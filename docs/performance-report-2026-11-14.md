# Reporte de performance — 2026-11-14

> Análisis estático, sin ejecutar ni medir. Los porcentajes son estimaciones
> razonadas a partir del código y de las mediciones que ya tiene el repo
> (`docs/perf/`, `docs/adr/0003-workers-del-runtime.md`). No son mediciones.

## Resumen

**Alcance:** todo el repositorio. Daemon `kumod` (crates `domain`, `application`,
`infrastructure`, `grpc`, `daemon`) y la UI Flutter `kumo-ui` en lo que consume
del daemon. No entraron en el alcance el build, el empaquetado ni `target/`.

**Stack:** Rust 2024 + tokio (con **2 workers** por defecto, ADR-0003), tonic/prost
para gRPC en loopback, SQLite (rusqlite, WAL) como caché local, `git` y `gh`
lanzados como procesos, `notify` (FSEvents / ReadDirectoryChanges / inotify)
para vigilar archivos, `ureq` bloqueante para las APIs (GitHub, GitLab,
Bitbucket, Jira, Todoist). UI en Flutter con `grpc` de Dart.

**Evidencia previa:** los benchmarks de M0 (terminales) y M4 (tareas) cumplen
sus presupuestos con margen. Leí el camino de la terminal (pump, `BatchBuilder`,
`OutputHub`, `ReplayBuffer`, `CommandMarks`, `GridRenderer`) y el del tablero
de tareas (deltas por `tasks_version`, ETags, caché por mtime en Obsidian), y no
encontré nada que valga la pena cambiar. Lo que **no** tiene benchmark es todo
lo que pasa por `git`: el estado de los worktrees, el panel de cambios y el
watcher del workspace. Ahí están los hallazgos de mayor impacto.

**Hallazgos: 7.** Los tres de mayor impacto:

1. **H1: el watcher reacciona a archivos ignorados por git.** Durante un
   `cargo build`, `npm install` o similar, el daemon relee git en bucle
   (cada ~300 ms el workspace y cada ~150 ms el panel de cambios). Estimado:
   **−90–99 %** de las relecturas de git disparadas durante un build cuya
   salida está en `.gitignore`.
2. **H2: cada lectura de cambios lanza entre 8 y 12 procesos `git` en serie**,
   y el diff "Committed" corre un `git status` completo solo para saber la
   rama. Estimado: **−40–65 %** de latencia por actualización del panel de
   cambios en repos chicos y medianos (−15–30 % en repos grandes).
3. **H3: el lock del `WorkspaceService` se mantiene tomado mientras corren
   procesos `git`.** Cualquier RPC del panel de cambios (leer archivo, diff,
   stage…) espera a que termine la relectura en curso. Estimado: **−70–95 %**
   en el p99 de esas RPC mientras hay una relectura en curso.

## Tabla de hallazgos

Orden: impacto esperado en relación con el esfuerzo y el riesgo.

| # | Título | Ubicación | Métrica | Mejora estimada | Confianza | Esfuerzo |
|---|---|---|---|---|---|---|
| H1 | El watcher no filtra archivos ignorados por git | `crates/infrastructure/src/watch/mod.rs:23-49` | Relecturas de git y CPU de `kumod` durante un build | −90–99 % de las relecturas durante el build | Alta (mecanismo) / media (magnitud) | Medio |
| H2 | `status` lanza 8–12 procesos `git` en serie | `crates/infrastructure/src/git/changes.rs:111-151, 213-221` | Latencia de cada actualización de `Git.WatchStatus` y del diff Committed | −40–65 % (repos chicos o medianos), −15–30 % (repos grandes) | Media | Chico–medio |
| H3 | Lock del workspace tomado durante git; statuses en serie | `crates/application/src/workspace/service.rs:113-136, 314-345, 422-488, 524-530` | p99 de las RPC de Changes durante una relectura; duración de `read_repo` | p99 −70–95 % durante relecturas; `read_repo` −40–70 % con ≥3 worktrees | Media | Medio |
| H4 | Doble relectura del repo por cada cambio con el panel abierto | `crates/application/src/changes/service.rs:83-85` + `workspace/sync.rs:42-51` | Procesos `git` por cambio en disco | −20–35 % de los procesos por cambio | Alta (mecanismo) / media (magnitud) | Chico |
| H5 | Snapshot de agentes completo, con hasta 80 eventos por sesión, en cada cambio | `crates/application/src/agents/service.rs:670-678`, `grpc/src/mapping/agents.rs:59,125-131`, `kumo-ui/lib/engine/engine_agents_source.dart:47-53` | Bytes/s del stream `Agents.Watch` y CPU de decodificación y rebuild en la UI | −80–95 % de bytes con ≥3 sesiones | Media | Medio |
| H6 | La persistencia de tareas bloquea el push y reescribe la fuente entera | `crates/application/src/tasks/service.rs:603-610, 673-681`, `infrastructure/src/storage/task_store.rs:122-193` | Latencia "edición externa → push" (hoy 247 ms) y de `SetStatus` | −12–25 % del total (−30–60 % de la parte que no es asentamiento) | Baja–media | Chico–medio |
| H7 | Detalle de Jira: issue y comentarios en serie | `crates/infrastructure/src/tasks/jira.rs:401-408` | Latencia de `GetTask` (Jira, sin caché) | −30–45 % | Media | Chico |

---

## Detalle de cada hallazgo

### H1: el watcher no filtra archivos ignorados por git

**Ubicación**

- `crates/infrastructure/src/watch/mod.rs:23-49` (filtro de eventos)
- `crates/application/src/workspace/sync.rs:42-51` (bucle que relee el repo)
- `crates/application/src/changes/service.rs:65-93` (bucle del panel de cambios)

**Cuello de botella actual**

`NotifyWatcher` vigila en modo recursivo el checkout principal y cada worktree.
El único filtro descarta `.git/objects`:

```rust
// watch/mod.rs
if let Ok(event) = event
    && !matches!(event.kind, EventKind::Access(_))
    && event.paths.iter().any(|p| relevant(p))
{
    on_change();
}
...
fn relevant(path: &Path) -> bool {
    !path.components().collect::<Vec<_>>().windows(2)
        .any(|w| w[0].as_os_str() == ".git" && w[1].as_os_str() == "objects")
}
```

Cualquier escritura en `target/`, `node_modules/`, `build/`, `.dart_tool/`,
`dist/`, etc. dispara dos bucles:

- **Workspace** (`sync.rs`): marca el repo como sucio, espera 300 ms y corre
  `refresh_repo`, que lanza `git worktree list` y un `git status` por cada
  worktree (`service.rs:461-488`).
- **Panel de cambios** (`changes/service.rs`), si está abierto: espera 150 ms y
  corre `GitChanges::status` (8–12 procesos, ver H2) y, si algo cambió,
  `refresh_worktree` (ver H4).

Un build escribe archivos sin parar durante decenas de segundos o minutos, así
que los dos bucles corren todo ese tiempo, uno detrás del otro. Ninguno de esos
archivos cambia la salida de `git status`, porque son ignorados. El costo se
agrava porque Kumo desactiva `core.fsmonitor` a propósito (`git/cli.rs:60`): cada
`git status` recorre el árbol entero. Además compite por CPU e I/O con el
propio build. En Linux, la vigilancia recursiva de inotify registra un watch
por directorio, incluidos `node_modules` y `target`, y puede agotar
`max_user_watches`.

**Approach propuesto**

1. En `NotifyWatcher::watch`, construir por cada raíz vigilada un matcher de
   ignores con el crate `ignore` (`ignore::gitignore::GitignoreBuilder`),
   cargando `.gitignore` de la raíz y de los subdirectorios, `.git/info/exclude`
   y `core.excludesFile` (se lee una sola vez con `git config --path
   core.excludesFile`, o se omite). Solo lee y parsea archivos, no ejecuta nada.
2. Descartar un evento si **todos** sus paths:
   - están fuera de `.git/` (todo lo de `.git/` salvo `objects/` sigue siendo
     relevante: `HEAD`, `index`, `refs/`, `worktrees/`), y
   - están dentro de un **directorio** ignorado (`matched_path_or_any_parents`
     da `Ignore` para un ancestro). Limitarlo a directorios ignorados evita el
     caso de un archivo **trackeado** que además coincide con un patrón de
     `.gitignore` (git lo sigue mostrando en el status).
3. Reconstruir el matcher cuando el evento toca un `.gitignore` o
   `.git/info/exclude`.
4. De paso, reemplazar el `collect::<Vec<_>>()` de `relevant` por una
   iteración con `peekable` o con `Path::ancestors`. Hoy aloca un `Vec` por
   path y por evento, y durante un build llegan miles de eventos.
5. En Linux (opcional): en vez de `RecursiveMode::Recursive`, recorrer el árbol
   salteando los directorios ignorados y registrar cada directorio en modo
   `NonRecursive`. Así se evita el límite de inotify. Va en
   `infrastructure/platform/linux.rs`, según la regla de una implementación por
   SO.

Los dos servicios usan el mismo `NotifyWatcher`, así que el cambio los cubre a
los dos. Tareas y docs usan el mismo puerto, pero vigilan vaults y no repos:
para ellos se puede desactivar el filtro con un flag del puerto.

**Mejora estimada**

- **Métrica:** cantidad de relecturas de git (`refresh_repo` y `read_status`)
  y CPU de `kumod` mientras corre un build en un repo del workspace.
- **Alcance:** daemon completo, durante builds y descargas de dependencias.
- **Rango:** −90–99 % de las relecturas disparadas durante el build, si la
  salida del build está en un directorio ignorado (el caso normal en Rust,
  Node, Flutter y Gradle). Hoy son ~1 relectura cada 0,3 s + duración de git
  (workspace) y ~1 cada 0,15 s + duración de git (panel). Con el filtro solo
  quedan las que provocan cambios reales en archivos trackeados o no ignorados.
- **Justificación:** el número de relecturas pasa de "proporcional a la
  duración del build" a "proporcional a los cambios reales". Para un build de
  60 s en un repo con 3 worktrees, eso son del orden de 100–200 relecturas del
  workspace (cada una con 1 + 3 procesos `git`). Si además el panel está
  abierto, se suman del orden de 200–400 ciclos de 8–12 procesos. Después del
  cambio quedan casi en cero.
- **Confianza:** alta en el mecanismo (se ve en el código). Media en la
  magnitud: depende del tamaño del repo (cuánto tarda `git status`) y de
  cuántos archivos escribe el build. Con un build chico y un repo chico, la
  ganancia absoluta en CPU es menor, pero el porcentaje se mantiene.

**Consideraciones de seguridad**

- No "arreglar" esto reactivando `core.fsmonitor`. Kumo lo desactiva para no
  ejecutar un programa que nombra la configuración del repo
  (`git/cli.rs:58-60` y su test `reading_a_repo_does_not_run_its_file_monitor`).
  El matcher de ignores solo lee archivos de texto.
- No descartar eventos dentro de `.git/` (salvo `objects/`): `HEAD`, `index`
  y `refs` son los que indican commits, checkouts y stages hechos desde una
  terminal.
- Si el matcher falla al construirse (un `.gitignore` ilegible), volver al
  comportamiento actual: vigilar todo.

**Esfuerzo y riesgos**

- Medio: una dependencia nueva (`ignore`, del mismo autor que ripgrep), unas
  100–150 líneas y tests.
- Riesgo: perder un evento relevante si el matcher descarta de más. La
  limitación a directorios ignorados y la excepción de `.git/` lo acotan. Como
  red de seguridad se puede mantener el refresh manual (`Workspace.Refresh`),
  que ya existe.

---

### H2: `GitChanges::status` lanza 8–12 procesos `git` en serie

**Ubicación**

- `crates/infrastructure/src/git/changes.rs:111-151` (`status`)
- `crates/infrastructure/src/git/changes.rs:62-96` (`base_ref`, `merge_base`)
- `crates/infrastructure/src/git/changes.rs:213-221` (`diff`, scope Committed)
- `crates/infrastructure/src/git/changes.rs:502-511` (`count_untracked`)

**Cuello de botella actual**

Cada vez que el panel de cambios se actualiza (`watch_status`, en cada cambio
en disco) se ejecuta, en serie:

```rust
let raw = self.git(worktree, ["status", "--porcelain=v2", "--branch", "--untracked-files=all", "-z"])?; // 1
if self.has_head(worktree) {                                   // 2  rev-parse --verify HEAD
    let numstat = self.git(worktree, ["diff", "-z", "--numstat", "HEAD"])?;  // 3
    ...
}
for change in ... Untracked { count_untracked(worktree, change); }  // lee cada archivo no trackeado (≤1 MiB)
if let Some(base) = self.base_ref(worktree, ...)               // 4  symbolic-ref origin/HEAD
                                                               // 5..9 rev-parse --verify <cand>^{commit} (1 a 5)
    && let Some(merge_base) = self.merge_base(worktree, &base) // 10 merge-base HEAD base
{
    let names   = self.git(worktree, ["diff", "-z", "--name-status", "-M", &merge_base, "HEAD"])?; // 11
    let numstat = self.git(worktree, ["diff", "-z", "--numstat",     "-M", &merge_base, "HEAD"])?; // 12
}
```

Lo típico, con `origin/HEAD` configurado, son 8 procesos. Sin `origin/HEAD`, o
en una rama sin base, son hasta 12. En macOS, cada `fork`+`exec` de git más el
arranque (lectura de configuración y descubrimiento del repo) cuesta del orden
de 3–8 ms aunque el comando no haga nada. Encima corren uno detrás del otro.

En el diff con scope **Committed** (`changes.rs:213-215`) se corre un
`git status` completo, que recorre todo el árbol de trabajo, solo para leer
`branch.head`. Después vienen `base_ref` y `merge_base` otra vez.

`count_untracked` lee entero cada archivo no trackeado de hasta 1 MiB en cada
actualización. Con `--untracked-files=all`, una carpeta nueva no ignorada con
muchos archivos se relee completa en cada ciclo.

**Approach propuesto**

1. **`has_head` sin proceso:** la salida de `git status --porcelain=v2
   --branch` ya trae `# branch.oid (initial)` cuando no hay HEAD. Parsearlo en
   `parse_status` y eliminar el `rev-parse --verify HEAD` (−1 proceso). Lo
   mismo aplica a `diff` (scope Working) y a `log`.
2. **Base cacheada por worktree:** guardar en un `Mutex<HashMap<PathBuf,
   (Option<String>, clave)>>` dentro de `GitCli` el resultado de `base_ref`,
   con una clave de invalidación barata: la mtime de
   `<git-common-dir>/refs/remotes/origin/HEAD` y de `packed-refs`, o
   invalidarla en `fetch`, `pull` y `push`. Si no se quiere cachear, resolverla
   en **un solo** proceso:
   `git for-each-ref --format=%(refname:short) refs/remotes/origin/HEAD
   refs/remotes/origin/main refs/remotes/origin/master refs/heads/main
   refs/heads/master` y elegir en Rust el primero que exista según la
   prioridad actual (−1 a −5 procesos).
3. **Sin `merge-base` aparte, con un solo diff:** usar la sintaxis de tres
   puntos, que calcula el merge-base dentro de git, y pedir los dos formatos en
   una sola corrida: `git diff -z --raw --numstat -M <base>...HEAD`. La salida
   `--raw` trae la letra de estado (la que hoy se saca de `--name-status`) y los
   paths. Hay que adaptar `parse_name_status` al formato raw (`:mode mode sha
   sha STATUS\0path\0[path\0]`) (−2 procesos).
4. **Rama sin `status` en el diff Committed:** reemplazar el `git status` de
   `changes.rs:214` por `git symbolic-ref --quiet --short HEAD` (no recorre el
   árbol) y aplicar el punto 3 (`<base>...HEAD -- <file>`).
5. **Caché de líneas de no trackeados:** guardar `(path, len, mtime) →
   (additions, binary)` por worktree y releer solo si cambió el tamaño o la
   mtime.

Resultado: `status` pasa de 8–12 procesos a **3** (status, numstat contra HEAD
y el diff combinado contra la base) más, ocasionalmente, 1 para resolver la
base. El diff Committed pasa de 5–9 procesos, uno de ellos un `status`
completo, a 2–3.

**Mejora estimada**

- **Métrica:** latencia desde un cambio en disco hasta que el panel de cambios
  recibe el nuevo `WorktreeChanges`, y latencia del diff Committed.
- **Alcance:** panel de cambios (`Git.WatchStatus`, `Git.Status`, `Git.Diff`).
  También baja la carga del daemon en cada ciclo de H1 y H4.
- **Rango:** −40–65 % en repos chicos o medianos, donde el costo fijo por
  proceso domina. −15–30 % en repos grandes, donde domina el `git status` en
  sí. Para el diff Committed en un repo grande: −50–80 %, porque desaparece un
  `status` completo.
- **Justificación:** se eliminan 5–9 procesos de ~3–8 ms cada uno, o sea
  25–70 ms, sobre un total estimado de 60–150 ms en repos chicos o medianos.
  En repos grandes, donde `status` + `diff HEAD` pueden tardar 200–500 ms, el
  ahorro absoluto es parecido y el relativo, menor.
- **Confianza:** media. El costo por proceso depende del SO; en Windows suele
  ser mayor y la ganancia sería más alta. El repo no tiene un benchmark de git
  que sirva de base.

**Consideraciones de seguridad**

- Mantener `-c core.fsmonitor=false`, `GIT_OPTIONAL_LOCKS=0`,
  `GIT_TERMINAL_PROMPT=0` y `--no-ext-diff` en todos los comandos nuevos.
- La base que se interpola en `<base>...HEAD` tiene que salir de la salida de
  git (`for-each-ref` o `symbolic-ref`), nunca de la request. Los paths siguen
  después de `--`.
- La caché de bases y de no trackeados no guarda secretos. Si se guarda en
  memoria por worktree, se descarta cuando el worktree desaparece.

**Esfuerzo y riesgos**

- Chico–medio: cambios acotados a `git/changes.rs` y `git/cli.rs`, más tests
  de los parsers nuevos (raw + numstat combinados).
- Riesgo: diferencias de formato entre `--name-status` y `--raw` en renames y
  copias. Conviene un test con renames (`R100`) y archivos binarios, como el
  que ya existe para numstat. Si la caché de la base no se invalida bien,
  queda mal la base después de que cambia la rama por defecto del remoto (caso
  raro).

---

### H3: lock del workspace tomado durante git, statuses en serie y `canonicalize` repetido

**Ubicación**

- `crates/application/src/workspace/service.rs:113-136` (`refresh`)
- `crates/application/src/workspace/service.rs:326-345` (`refresh_worktree`, `refresh_repo`)
- `crates/application/src/workspace/service.rs:422-451` (`reread`, `reread_if_changed`)
- `crates/application/src/workspace/service.rs:461-488` (`read_repo`)
- `crates/application/src/workspace/service.rs:314-322, 524-530` (`known_worktree`, `same_path`)
- `crates/application/src/changes/service.rs:247-252` (todas las RPC de Changes pasan por `known_worktree`)

**Cuello de botella actual**

`state` es un `tokio::sync::Mutex<State>` que se mantiene tomado mientras se
espera a los procesos `git`:

```rust
pub async fn refresh_repo(&self, repo: &Path) {
    let mut state = self.state.lock().await;                 // lock tomado…
    if let Some(owner) = state.repos.get(repo).cloned() {
        self.reread_if_changed(&mut state, owner).await;     // …mientras corre read_repo (git worktree list + N × git status)
    }
}
```

`refresh()` hace lo mismo para todos los repos a la vez: corre `join_all` con
el lock tomado. `read_repo` lee el status de cada worktree **en serie**:

```rust
for worktree in &mut worktrees {
    worktree.status = git.status(&worktree.path).unwrap_or_default();
}
```

Mientras tanto, **todas** las RPC del panel de cambios (`read_file`, `diff`,
`list_files`, `stage`, `commit`…) llaman a `known_worktree`, que necesita el
mismo lock. Las relecturas son frecuentes (H1 y H4), y en el arranque se hace
un `refresh()` de todo. Abrir un archivo o un diff puede quedar esperando lo
que tarden `1 + W` procesos `git` de cada repo en relectura.

Además, `known_worktree` compara contra cada worktree con `same_path`, que
llama dos veces a `std::fs::canonicalize` por candidato (cuando no hay igualdad
literal). Son syscalls bloqueantes en un worker de tokio, y el daemon tiene
solo 2 (ADR-0003). Los paths guardados ya están canonicalizados
(`GitCli::worktrees` aplica `platform::canonical`), así que canonicalizarlos de
nuevo es trabajo repetido.

**Approach propuesto**

1. **Leer git fuera del lock.** En `refresh_repo`, `refresh_worktree` y
   `refresh`: tomar el lock, clonar el `Repo`, soltarlo, correr `read_repo` en
   `spawn_blocking`, y volver a tomar el lock solo para aplicar el resultado y
   publicar. Para no pisar una lectura más nueva con una más vieja, guardar por
   repo un contador de generación (`read_gen`) que se incrementa al lanzar cada
   lectura. Al aplicar, descartar el resultado si ya se aplicó uno de una
   generación mayor, o si el repo dejó de estar en `state.repos` (namespace
   borrado mientras tanto).
2. **Coalescer relecturas del mismo repo.** Si ya hay una lectura en vuelo
   para ese repo, marcarlo "sucio otra vez" y relanzar una sola al terminar, en
   lugar de encolar N lecturas. Esto combina bien con H4.
3. **Statuses de worktrees en paralelo** dentro de `read_repo`, con
   `std::thread::scope` (ya corre en el pool bloqueante) y un tope chico, por
   ejemplo 4 en simultáneo, para no saturar el disco.
4. **`known_worktree` sin lock y con un solo `canonicalize`:** resolverlo
   contra `self.published.borrow()` (el `watch` del snapshot, sin esperar el
   mutex) o contra un índice `HashSet<PathBuf>` de worktrees canónicos que se
   recalcula en `publish`. Canonicalizar **una vez** el path pedido, y en
   `spawn_blocking` si se quiere ser estricto con los workers, y comparar por
   igualdad exacta. Ojo: hoy `known_worktree` busca en `state.repos` (incluye
   repos registrados que ya no están en un namespace), y el snapshot solo
   tiene los referenciados. Hay que decidir si se mantiene ese
   comportamiento (índice construido desde `state.repos`) o se restringe a
   los referenciados.
5. Las mutaciones (`create_worktree`, `remove_worktree`, `save_namespace`)
   pueden seguir serializadas con el lock: son acciones del usuario, poco
   frecuentes, y su orden importa.

**Mejora estimada**

- **Métrica 1:** p99 de latencia de las RPC de `Git.*` que pasan por
  `known_worktree` (abrir archivo, diff, stage) mientras hay una relectura en
  curso. **Rango:** −70–95 %. Hoy la espera es igual a la duración de la
  relectura en curso, del orden de 50 ms a más de 1 s según el tamaño del repo
  y la cantidad de worktrees. Después del cambio es del orden de
  microsegundos a 1 ms (lectura del `watch` + un `canonicalize`). Sin
  relecturas en curso, la ganancia es despreciable.
- **Métrica 2:** duración de `read_repo` para un repo con W worktrees.
  **Rango:** −40–70 % con W ≥ 3. Pasa de `W × t_status` a algo cercano a
  `t_status` más contención de I/O.
- **Confianza:** media. El efecto depende de cuántas relecturas haya
  (fuertemente ligado a H1) y del tamaño de los repos. Si se implementa H1
  primero, la frecuencia de colisión baja, pero el arranque (`refresh()` de
  todo) y los cambios reales siguen bloqueando.

**Consideraciones de seguridad**

- `known_worktree` es la **frontera de autorización** del panel de cambios
  ("Any other path is refused", `changes/service.rs:35-36`). Hay que mantener
  la comparación por igualdad exacta de paths canónicos, sin pasar a
  "empieza con", y canonicalizar el path pedido para resolver symlinks antes
  de comparar. Un path con `..` o un symlink que apunte afuera no debe
  coincidir.
- Leer fuera del lock introduce una carrera de "lost update". El contador de
  generación del punto 1 la resuelve: no aplicar resultados viejos ni
  resultados de repos que ya no están.
- Usar un snapshot apenas viejo para autorizar puede aceptar, por unos
  milisegundos, un worktree recién borrado. El directorio ya no existe, así
  que las operaciones fallan solas. Es aceptable, pero conviene dejarlo
  anotado en el código.

**Esfuerzo y riesgos**

- Medio: toca el corazón del `WorkspaceService`. Los tests actuales de
  workspace y los de integración (`crates/daemon/tests/`) cubren buena parte.
  Conviene agregar uno de concurrencia: una relectura lenta (fake de `Git` con
  sleep) y una RPC de Changes que no debe esperarla.
- Riesgo: publicar estados intermedios en otro orden. Con el contador de
  generación por repo, el último estado aplicado es siempre el más nuevo.

---

### H4: doble relectura del repo por cada cambio con el panel de cambios abierto

**Ubicación**

- `crates/application/src/changes/service.rs:78-86` (dentro de `watch_status`)
- `crates/application/src/workspace/sync.rs:42-51` (bucle del workspace)
- `crates/application/src/changes/service.rs:139, 160, 201, 268` (acciones que también refrescan)

**Cuello de botella actual**

Con el panel de cambios abierto en un worktree, un mismo cambio en disco
dispara **dos** watchers sobre las mismas carpetas:

```rust
// changes/service.rs — watch_status
let status = service.read_status(worktree.clone()).await;   // 8–12 procesos (H2)
if last.as_ref() != Some(&status) {
    ...
    if last.is_some() {
        service.workspace.refresh_worktree(&worktree).await; // read_repo: 1 + W procesos
    }
}
```

```rust
// workspace/sync.rs — el mismo evento marca el repo sucio
() = wake.notified() => {
    tokio::time::sleep(SETTLE).await;
    ...
    for repo in repos { service.refresh_repo(&repo).await; }  // read_repo otra vez: 1 + W procesos
}
```

El sync del workspace ya vigila el checkout principal (que incluye
`.git/worktrees/…`) y los worktrees de afuera, así que el `refresh_worktree`
del panel relee algo que el sync va a releer 150 ms después. Lo mismo pasa
con las acciones (`commit`, `stage`, `push`…): llaman a `refresh_worktree` y,
como tocan `.git/index` o `HEAD`, también disparan el sync.

**Approach propuesto**

- Agregar a `WorkspaceService` un método `mark_dirty(&self, repo_or_worktree:
  &Path)` que alimente el mismo conjunto `dirty` y el mismo `Notify` del bucle
  de `sync.rs` (pasarlos al servicio o exponer un `mpsc`). Así todas las
  relecturas pasan por un solo coalescedor.
- En `watch_status`, reemplazar `refresh_worktree(...).await` por
  `mark_dirty(...)`.
- En las acciones del usuario, mantener una relectura inmediata si se quiere
  que el sidebar responda enseguida, pero también a través del coalescedor
  (marcar y despertar sin esperar el `SETTLE`), para que el evento del watcher
  que llega después encuentre el repo limpio y no lo relea.
- Combinado con el punto 2 de H3 (no encolar lecturas del mismo repo si hay
  una en vuelo).

**Mejora estimada**

- **Métrica:** procesos `git` lanzados por cada cambio en disco con el panel
  de cambios abierto.
- **Alcance:** daemon, mientras el panel está abierto (el caso de un agente
  editando archivos mientras el usuario mira los cambios).
- **Rango:** −20–35 %. Hoy, por cambio: 8–12 (status del panel) + 2 × (1 + W)
  (dos `read_repo`). Con W = 3 son ~16–20 procesos, y quitar un `read_repo`
  ahorra 4. Combinado con H2, que baja el status a 3, el ahorro relativo de
  H4 sube a ~40 % (11 → 7).
- **Confianza:** alta en el mecanismo, media en la magnitud (depende de W y
  de si los eventos del sync y del panel caen en la misma ventana de 300 ms).

**Consideraciones de seguridad**

Ninguna.

**Esfuerzo y riesgos**

- Chico: decenas de líneas en `workspace/sync.rs`, `workspace/service.rs` y
  `changes/service.rs`.
- Riesgo: el contador del sidebar se actualiza un poco más tarde (hasta el
  `SETTLE` de 300 ms en vez de inmediato) en el caso del watcher. Para las
  acciones del usuario se evita despertando sin esperar.

---

### H5: el snapshot de agentes viaja completo, con todos los eventos, en cada cambio

**Ubicación**

- `crates/application/src/agents/service.rs:670-678` (`update`: clona el snapshot completo)
- `crates/application/src/agents/monitor.rs:85-116` (actualiza la sesión hasta 1 vez/s por agente, más cada evento)
- `crates/application/src/agents/terminal_agents.rs:206-217`
- `crates/grpc/src/services/agents.rs:219-227` y `crates/grpc/src/mapping/agents.rs:59, 125-131` (serializa todas las sesiones con sus eventos)
- `kumo-ui/lib/engine/engine_agents_source.dart:47-53` (la UI reconstruye la lista entera y notifica)
- `crates/domain/src/agents/session.rs:62-63, 124` (`events` de hasta 80 por sesión)

**Cuello de botella actual**

Cada cambio de **una** sesión hace dos cosas:

1. Clona el `AgentsSnapshot` entero: todas las sesiones, cada una con
   `prompt`, `context` y hasta 80 `events` con texto.
   ```rust
   fn update(&self, change: impl FnOnce(&mut AgentsSnapshot)) {
       let snapshot = { let mut s = self.lock(); change(&mut s); s.version += 1; s.clone() };
       self.published.send_replace(Arc::new(snapshot));
   }
   ```
2. Hace que el stream `Agents.Watch` convierta a protobuf y envíe **todas**
   las sesiones con todos sus eventos (`events:
   session.events.into_iter().map(agent_event_to)`). La UI decodifica todo,
   rearma `_runs` y llama a `notifyListeners()`.

El monitor de cada agente actualiza su sesión cuando cambia la última línea
(como mucho 1 vez/s), cuando cambia el estado o cuando detecta acciones. Con N
sesiones activas son ~N actualizaciones/s, cada una de tamaño proporcional a
N × 80 eventos: el costo crece como **O(N²)**. Las sesiones terminadas siguen
en el snapshot hasta que se descartan, así que también cuentan en N.

El stream de tareas ya resuelve este mismo problema con deltas por
`tasks_version` (`grpc/src/services/tasks.rs:58-60`).

**Approach propuesto**

1. **Delta por sesión en el stream**, como en tareas: agregar a cada
   `AgentSession` un `version` (o reutilizar uno por sesión) y, en
   `AgentsGrpc::watch`, mantener en el `scan` un `HashMap<id, version>` de lo
   enviado. Mandar solo las sesiones que cambiaron más los ids que
   desaparecieron. El primer mensaje del stream va completo. Requiere un campo
   nuevo en el proto (`changed`, `removed_ids` o un `full: bool`) y que la UI
   haga el merge en `_runs`.
2. **Eventos fuera del mensaje frecuente** (complementario o alternativo): los
   eventos casi no cambian entre actualizaciones de "última línea". Mandarlos
   solo cuando cambia su cantidad o su último elemento (un `events_version`),
   o exponerlos con una RPC aparte que la UI llame al abrir el detalle de una
   corrida.
3. **Lado Rust:** guardar las sesiones como `Arc<AgentSession>` dentro del
   snapshot y usar `Arc::make_mut` sobre la que cambia, para que el clon del
   snapshot sea O(N) punteros y no O(N × eventos).
4. **Lado UI:** notificar solo si cambió algo visible y reutilizar los
   `AgentRun` de las sesiones que no cambiaron, para que los widgets con
   comparación por identidad no se reconstruyan.

**Mejora estimada**

- **Métrica:** bytes/s del stream `Agents.Watch` y CPU de serialización (daemon)
  más decodificación y rebuild (UI).
- **Alcance:** daemon y UI, con varias sesiones de agentes abiertas.
- **Rango:** −80–95 % de bytes con N ≥ 3 sesiones. Ejemplo con N = 5 y eventos
  de ~150 B: hoy ~5 actualizaciones/s × 5 sesiones × 80 eventos × 150 B ≈
  300 KB/s, más el clon equivalente en el daemon. Con delta por sesión y
  eventos solo cuando cambian: ~5 × (1 sesión sin eventos ≈ 0,5–1 KB) ≈
  2,5–5 KB/s, más un envío ocasional de eventos.
- **Confianza:** media. El tamaño real de los eventos y de `prompt` y
  `context`, y la frecuencia de actualización (depende de cuánto imprime cada
  agente), no se pueden medir de forma estática. Con N = 1 la ganancia es
  baja: queda solo el ahorro de no reenviar eventos.

**Consideraciones de seguridad**

- El stream debe seguir siendo por perfil (`services_of`) y autenticado como
  hoy. El delta no debe mezclar sesiones de otro perfil.
- Los eventos y el `prompt` pueden contener texto sensible (comandos,
  contenido de tareas). Si se agrega una RPC aparte para los eventos, tiene
  que validar que la sesión pertenece al perfil del llamador.

**Esfuerzo y riesgos**

- Medio: proto, mapping, servicio gRPC, UI y tests de la UI.
- Riesgo: que la UI se desincronice si pierde un delta. El primer mensaje de
  cada stream va completo y el stream se reabre en cada reconexión
  (`engine_agents_source.dart:45-59`), así que una reconexión lo corrige.

---

### H6: la persistencia de tareas bloquea el push y reescribe la fuente entera

**Ubicación**

- `crates/application/src/tasks/service.rs:603-610` (`sync_source`: espera a persistir antes de publicar)
- `crates/application/src/tasks/service.rs:420-424, 673-681` (`set_status` → `persist_tasks`)
- `crates/infrastructure/src/storage/task_store.rs:122-193` (`replace_tasks`: `DELETE` + `INSERT` de todas las filas, con 4–5 `serde_json::to_string` por fila)

**Cuello de botella actual**

```rust
// sync_source
let tasks = blocking(move || connector.fetch(&reading, secret.as_deref())).await?;
let unchanged = self.lock().source(id).is_some_and(|v| *v.tasks == *tasks);
if !unchanged {
    blocking(move || store.replace_tasks(&id, &saved)).await?;   // ← en el camino crítico
}
Ok(tasks)
// …recién después: self.update(...) publica el tablero
```

- Una edición de **una** nota en un vault de 10.000 tareas: el conector de
  Obsidian solo reparsea esa nota (caché por mtime y tamaño), pero
  `replace_tasks` borra e inserta las 10.000 filas y serializa a JSON labels,
  assignee, parent, sprint y relations de cada una. El tablero se publica
  **después** de esa transacción.
- `set_status` en una tarea: llama a `persist_tasks`, que reescribe la fuente
  entera. En Obsidian, la escritura del archivo dispara además el watcher, y
  `sync_source` la vuelve a reescribir entera.

El benchmark M4 mide "edición externa de una nota hasta el push" en
**247 ms**, con 150 ms de asentamiento. Quedan ~97 ms de trabajo, y la
reescritura de 10k filas es la candidata principal dentro de ese tiempo (el
reparse de una nota y el stat de 500 archivos son baratos en comparación).

**Approach propuesto**

1. **Publicar antes de persistir:** en `sync_source`, aplicar `self.update(...)`
   con las tareas nuevas y lanzar la persistencia después, en segundo plano.
   La caché SQLite solo se usa para arrancar rápido.
2. **Serializar las escrituras por fuente:** usar un `tokio::sync::Mutex`
   por fuente o una cola de un solo elemento ("última versión gana") con el
   `tasks_version` publicado. Así una persistencia vieja no pisa una nueva, ni
   la de `set_status` (que corre en el contexto de la RPC) choca con la del
   worker.
3. **Escritura incremental:** en vez de `DELETE` + `INSERT` de todo, comparar
   contra lo que había (el `Arc<[Task]>` anterior ya está en memoria) y hacer
   `INSERT … ON CONFLICT DO UPDATE` solo de las filas que cambiaron,
   `DELETE` de las que desaparecieron y `UPDATE position` si cambió el orden.
   Para `set_status`, un `UPDATE tasks SET status = ?, source_status = ? WHERE
   source_id = ? AND external_id = ?` de una fila, con SQL parametrizado como
   el resto del store.
4. Opcional: en `migrations.rs`, un paso nuevo con `CREATE INDEX tasks_by_position
   ON tasks (source_id, position)` evitaría el ordenamiento temporal de
   `tasks()` al arrancar. El impacto es chico: hoy carga 10k en 7,8 ms.

**Mejora estimada**

- **Métrica:** latencia "edición externa → push" del escenario `kumo-bench
  tasks` (hoy 247 ms) y latencia de `Tasks.SetStatus` en fuentes grandes.
- **Alcance:** fuentes de tareas con miles de tareas (Obsidian y Bear sobre
  todo; Jira y Todoist sincronizan cada 180 s y no se notaría).
- **Rango:** −30–60 % de la parte que no es asentamiento (~97 ms), lo que da
  −12–25 % del total medido (247 → ~190–215 ms). En `SetStatus` se ahorra una
  transacción de 10k filas, del orden de decenas de ms.
- **Justificación:** el push deja de esperar una transacción proporcional al
  tamaño de la fuente. Lo que queda (stat, parse, comparación y clon del
  tablero) no depende de SQLite.
- **Confianza:** baja–media. No hay una medición que separe cuánto de los
  ~97 ms es SQLite y cuánto es parse, comparación y armado del snapshot.

**Consideraciones de seguridad**

- Mover la persistencia a segundo plano introduce una **condición de
  carrera** entre escrituras de la misma fuente. El punto 2 es obligatorio,
  no opcional.
- El SQL incremental tiene que seguir parametrizado (`params![…]`), como el
  resto del store. No armar `IN (…)` concatenando ids.
- Si la persistencia en segundo plano falla, loguearla como hoy (`"couldn't
  cache tasks"`) sin incluir contenido de las tareas.

**Esfuerzo y riesgos**

- Chico (puntos 1 y 2) a medio (punto 3).
- Riesgo: si el daemon se cierra entre el push y la persistencia, la caché
  queda una versión atrás. Es aceptable porque la próxima sincronización la
  corrige, y hoy pasa lo mismo si el daemon se cae a mitad de la transacción.

---

### H7: detalle de Jira, issue y comentarios en serie

**Ubicación:** `crates/infrastructure/src/tasks/jira.rs:401-408`

**Cuello de botella actual**

```rust
let issue = self.get(&account, &format!("/rest/api/3/issue/{key}?fields={}", ...))?; // RTT 1
let comments = self.comments(&account, key)?;                                          // RTT 2 (+ páginas)
...
if !detail.subtasks.is_empty() || detail.task.kind == TaskType::Epic {
    self.search(&account, &jql, &fields, MAX_CHILDREN)                                 // RTT 3 (depende de 1)
}
```

El issue y sus comentarios son independientes, pero se piden uno después del
otro. Contra Jira Cloud, cada request cuesta del orden de 150–400 ms. Abrir el
detalle de un ticket sin caché (o con `refresh`) cuesta dos o tres RTT en
serie.

**Approach propuesto**

Como `ureq` es bloqueante y esto ya corre en `spawn_blocking`, pedir los
comentarios en paralelo con `std::thread::scope`:

```rust
let (issue, comments) = std::thread::scope(|s| {
    let comments = s.spawn(|| self.comments(&account, key));
    let issue = self.get(&account, &issue_url);
    (issue, comments.join().unwrap_or_else(|_| Err(TaskError::Source("…".into()))))
});
```

La búsqueda de hijos depende del issue (`subtasks` o `kind`) y queda
secuencial. Como alternativa, se puede lanzar en paralelo de forma
especulativa solo si la tarea conocida (`known`, que hoy se ignora como
`_known`) ya indica que tiene subtareas o que es un epic.

**Mejora estimada**

- **Métrica:** latencia de `Tasks.GetTask` para Jira sin caché.
- **Alcance:** abrir el detalle de un ticket de Jira.
- **Rango:** −30–45 %. Con 2 RTT pasa a ~1 RTT (−40–50 %). Con 3 RTT (epic o
  subtareas) pasa a 2 (−30–35 %). Más si `known` permite paralelizar también
  los hijos.
- **Confianza:** media. Depende de la latencia hacia el sitio de Jira y de
  que la cantidad de comentarios entre en una página (hasta 100).

**Consideraciones de seguridad**

Ninguna nueva: usa las mismas credenciales y los mismos endpoints. La
concurrencia es de 2 requests como máximo, así que no se acerca a los límites
de tasa de Jira.

**Esfuerzo y riesgos**

Chico (unas 20 líneas). Riesgo: si falla una de las dos requests, hay que
mantener la semántica actual: el error del issue gana y el de los comentarios
también corta. Hay que preservar ese orden.

---

## Cómo validar

El repo tiene `kumo-bench` (escenarios `hello`, `echo`, `throughput` y
`tasks`), pero **ninguno de git ni de agentes**. Propuesta:

1. **Contador de procesos `git` (H1, H2, H4).** Poner primero en el `PATH` del
   daemon un wrapper `git` que agregue una línea a un log (`$@` y timestamp) y
   haga `exec` al git real, o usar `GIT_TRACE2_EVENT=/tmp/trace.json` y contar
   eventos `start`. Medir:
   - procesos por cambio en disco con el panel de cambios abierto (antes y
     después de H2 y H4);
   - procesos durante un `cargo build` limpio de este mismo repo, con Kumo
     vigilándolo (antes y después de H1).
2. **CPU de `kumod` durante un build (H1).** `ps -o %cpu,rss -p <pid>` cada
   segundo durante el build, o Instruments → Time Profiler en macOS.
3. **Escenario nuevo `kumo-bench git` (H2, H3).** Generar un repo sintético
   (por ejemplo 20k archivos, 3 worktrees, una rama con commits sobre
   `origin/main`) y medir:
   - p50/p99 desde `touch` de un archivo trackeado hasta el mensaje de
     `Git.WatchStatus`;
   - p50/p99 de `Git.ReadFile` mientras se fuerza `Workspace.Refresh` en
     bucle (H3: hoy debería ver la duración del refresh en el p99);
   - duración de `Workspace.Refresh` con 1 y con 3 worktrees.
   Correrlo en macOS y en Windows, porque el costo por proceso varía mucho.
4. **Bytes del stream de agentes (H5).** Con los agentes falsos de los tests
   (`crates/daemon/tests`), abrir N = 1, 3 y 5 sesiones que impriman de forma
   continua. Contar bytes/s y mensajes/s recibidos en `Agents.Watch` desde un
   cliente de bench. En la UI, Flutter DevTools → Performance para medir el
   tiempo de frame y de rebuild con 5 agentes.
5. **Tareas (H6).** Volver a correr `kumo-bench tasks` y comparar "Edición
   externa… hasta el push" (hoy 247 ms). Agregar un caso de `SetStatus` sobre
   la fuente de 10k tareas.
6. **Jira (H7).** Con el servidor de prueba (`infrastructure/src/test_server.rs`)
   y una latencia artificial de 200 ms por request, medir `GetTask` antes y
   después.

## Limitaciones

- **Análisis estático.** No ejecuté nada. Los costos por proceso de git
  (3–8 ms), los RTT de Jira (150–400 ms) y los tamaños de eventos (~150 B) son
  supuestos típicos, no medidos en esta máquina. Cada estimación dice de qué
  dato depende.
- **No hay benchmarks de git, watcher ni agentes** que sirvan de base. Las
  estimaciones de H1–H5 no parten de números del repo. H6 sí parte del
  benchmark M4.
- **Windows y Linux:** las mediciones existentes son de macOS. El costo de
  lanzar procesos en Windows suele ser mayor (lo que agranda H2 y H4), y el
  límite de inotify en Linux hace que H1 sea más grave ahí. No verifiqué el
  comportamiento de `notify` en esos sistemas.
- **UI Flutter:** revisé cómo consume los streams del daemon y el renderer de
  la terminal (cachea filas en `ui.Picture`, sin problemas aparentes). No hice
  un análisis completo de rebuilds de widgets, del tamaño del bundle ni del
  arranque de la app.
- **Fuera de alcance:** build y empaquetado (`packaging/`), los conectores de
  Bear, Todoist, GitHub Issues y Confluence más allá de una lectura rápida, y
  el flujo de "agent defs" y "playground".
- **Observación que no es de performance:** `SqliteTaskStore`,
  `SqliteWorkspaceStore` y `SqliteAgentStore` abren cada uno su propia
  conexión al mismo `kumo.db` sin `busy_timeout`. Solo `SqliteHistoryStore` lo
  configura (`history_store.rs:76`). Con WAL, dos escrituras simultáneas desde
  conexiones distintas pueden fallar al instante con `SQLITE_BUSY` en vez de
  esperar. Es un tema de robustez, no de velocidad, pero se nota más si se
  implementa H6 (persistencia en segundo plano). Conviene configurar
  `busy_timeout` en todos los stores al mismo tiempo.
- **Descartado por impacto despreciable:** la lectura del llavero en cada poll
  de pipelines (una IPC cada 10–60 s), el escaneo de rollouts de Codex hasta
  encontrar el de la sesión (acotado a 3 días y a pocos segundos), y el
  busy-wait de 20 ms en `GhTokenFallback::gh` (el resultado se cachea 5 min).
