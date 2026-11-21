# Reporte de performance: release 0.9.0 (2026-11-21)

> Análisis estático, sin ejecutar ni medir. Los porcentajes son estimaciones
> razonadas a partir del código. No son mediciones. Cada una dice de qué dato
> depende.

## Resumen

**Alcance:** lo que entra en `release/0.9.0` sobre `v0.8.3` (`3c65b3d`), es
decir, los tres PRs mergeados en la rama:

- #102 `feat/global-search`: la paleta ⌘K (`kumo-ui/lib/overlays/global_search.dart`).
- #104 `feat/local-todos`: los TODOs locales que corren agentes (`domain/todos`,
  `application/todos`, `infrastructure/storage/todo_store.rs`,
  `grpc/services/todos.rs`, `daemon/todo_report.rs`,
  `kumo-ui/lib/views/todos_view.dart`, `engine_todos_source.dart` y los métodos
  de TODOs de `app_state.dart`), y el selector de skills para agentes
  (`agent_defs/service.rs::capabilities`, `widgets/skill_picker.dart`).
- #101 `fix/windows-traffic-lights`: no se revisó en detalle (ver Limitaciones).

Seguí también el código anterior que estas features empiezan a ejecutar, porque
ahí está la mayor parte del costo: `PullRequestService`, `EngineRepoActivity`,
`git/history.rs`, `git/branch.rs` y `quick_open.dart`.

**Stack:** daemon `kumod` en Rust 2024 + tokio (2 workers, ADR-0003), tonic
gRPC en loopback, SQLite (WAL), `git` lanzado como proceso, `ureq` bloqueante
contra GitHub, GitLab y Bitbucket. UI en Flutter (Dart) con `grpc`.

**Evidencia previa:** `docs/perf/` tiene benchmarks de terminal (M0), tareas
(M4) y watcher de git, y `docs/performance-report-2026-11-14.md` cubre el resto
del daemon. No hay ninguna medición de la UI: ni de la paleta, ni de la vista de
TODOs, ni del costo por elemento del fuzzy matching en Dart. Las estimaciones de
abajo no parten de números del repo.

**Hallazgos: 4.** Los tres de mayor impacto:

1. **P1: la paleta rankea todo en cada tecla, en el hilo de UI.** Recorre hasta
   50.000 archivos y 10.000 tickets por tecla y por cada respuesta asíncrona que
   llega, ordena todos los matches y arma hasta 500 resultados para mostrar 5.
   Estimado: **−70–90 %** del tiempo de `_rank()` por tecla en workspaces
   grandes.
2. **P2: abrir la paleta carga la actividad completa del repo, que la paleta
   no usa.** Son entre 9 y 39 procesos `git` en serie (un `git log` por rama,
   hasta 30) y una lista de PRs duplicada por cada ⌘K. Estimado: **−80–95 %**
   de los procesos `git` por apertura.
3. **P3: el chequeo de merges de TODOs corre siempre, salteando la caché.** El
   timer de 1 minuto sigue vivo mientras Tasks quedó en la vista "TODOs",
   aunque el usuario esté en otra pantalla. Además pide cada TODO en serie, con
   `refresh: true`: 4 procesos `git`, una lectura de token y una query GraphQL
   pesada por TODO. Estimado: **−90–99 %** de las requests al host y de los
   procesos `git` dedicados a detectar merges.

## Tabla de hallazgos

Orden: impacto esperado en relación con el esfuerzo y el riesgo.

| # | Título | Ubicación | Métrica | Mejora estimada | Confianza | Esfuerzo |
|---|---|---|---|---|---|---|
| P1 | La paleta rankea todos los grupos completos en cada tecla | `kumo-ui/lib/overlays/global_search.dart:378-422, 460-617`; `kumo-ui/lib/editor/quick_open.dart:20-108` | Tiempo de `_rank()` por tecla y por respuesta asíncrona (hilo de UI) | −70–90 % con ≥10k archivos o ≥2k tickets; −40–60 % en workspaces chicos | Media | Chico–medio |
| P2 | Abrir ⌘K carga historia de todas las ramas, ramas remotas y PRs que no usa | `global_search.dart:236-238`; `engine/engine_repo_activity.dart:31-46, 344-373`; `crates/infrastructure/src/git/history.rs:44-94` | Procesos `git` y llamadas al host por apertura de la paleta | −80–95 % de procesos `git`; −1 llamada duplicada de PRs por apertura | Alta (mecanismo) / media (magnitud) | Chico |
| P3 | Chequeo de merges de TODOs: siempre activo, en serie y sin caché | `kumo-ui/lib/views/todos_view.dart:44-55`; `kumo-ui/lib/app/app_state.dart:1744-1757`; `crates/application/src/pulls/service.rs:132-165, 334-357` | Requests al host y procesos `git` por hora para detectar merges | −70–95 % solo con gating por visibilidad; −90–99 % con consulta en lote por número de PR | Alta (mecanismo) / media (magnitud) | Chico (gating) / medio (lote) |
| P4 | Filas de la paleta: un `TextSpan` por carácter y remedición en cada hover | `global_search.dart:822-847, 869-934` | Tiempo de build y layout de la lista por cambio de hover o por tecla | −60–85 % | Baja–media | Chico |

---

## Detalle de cada hallazgo

### P1: la paleta rankea todos los grupos completos en cada tecla

**Ubicación**

- `kumo-ui/lib/overlays/global_search.dart:378-392` (`_changed`: rankea en cada cambio del texto)
- `kumo-ui/lib/overlays/global_search.dart:414-422` (`_reload`: rankea de nuevo con cada respuesta asíncrona)
- `kumo-ui/lib/overlays/global_search.dart:460-617` (`_rank`: todos los grupos, sin importar el tab)
- `kumo-ui/lib/overlays/global_search.dart:144-188` (`wordHits`, `rankText`)
- `kumo-ui/lib/editor/quick_open.dart:20-63, 82-108` (`fuzzyMatch`, `_boundary`, `rankFiles`)
- `kumo-ui/lib/app/app_state.dart:922` (`visibleFiles`) y `crates/application/src/changes/service.rs:16` (`MAX_LISTED_FILES = 50_000`)

**Cuello de botella actual**

En cada tecla, `_changed` llama a `_rank()`, que recalcula **todos** los grupos
sobre sus listas completas, sincrónicamente, en el isolate de UI:

```dart
m[SearchGroup.files] = [
  for (final (path, at) in rankFiles(q, s.visibleFiles, recent: recentFiles(s), limit: 500))
    () { ... return SearchResult(..., leading: FileIcon(path, size: 15), ...); }(),
];
...
m[SearchGroup.tickets] = q.isEmpty ? const [] : [
  for (final (t, hits) in rankText(q, s.tasks.tasks, key: ..., title: ..., rest: ...)) ...
];
...
_matches = m;
_cut();   // después se queda con 5 por grupo (tab All) o 60 (un tab)
```

Lo que cuesta, por elemento y por tecla:

- **Archivos** (hasta 50.000): `fuzzyMatch` vuelve a normalizar la query en cada
  path (`query.toLowerCase().replaceAll(' ', '')`), pasa el path a minúsculas
  (aloca un string), hace dos `indexOf` y dos `_subsequence` (cada uno aloca una
  lista) y puntúa hasta 4 candidatos. `_boundary` aloca strings de un carácter
  (`path[i - 1]`, `toUpperCase()`, `toLowerCase()`) por cada letra que coincide.
  Después `rankFiles` ordena **todos** los matches (con una query de 1 o 2
  letras, casi todos los archivos) y se queda con 500. Con la query vacía no es
  gratis: `files.toSet()` hashea los 50.000 paths y arma una lista de 50.000
  tuplas antes del `take(500)`.
- **Tickets** (hasta 10.000; el escenario M4 usa 10.000): `rankText` arma
  `[k, t, ...rest].join(' ')` por ticket, y `wordHits` vuelve a pasar la query
  a minúsculas, construye un `RegExp(r'\s+')` nuevo y pasa el texto a
  minúsculas. Para los que coinciden, repite `wordHits` sobre el título.
- Se arman `SearchResult` (con un widget `FileIcon`) para hasta 500 archivos y
  para todos los demás matches, aunque `_cut` muestre 5 por grupo en All.

`_reload` repite todo esto con cada respuesta que llega: el log, los PRs, los
docs y cada `notifyListeners` de `EngineRepoActivity` (3 al abrir, ver P2). Al
abrir la paleta hay unos 6 rankeos completos antes de que el usuario escriba.

**Approach propuesto**

1. **Índice precalculado al abrir la paleta.** Por archivo: el path en
   minúsculas y el índice del nombre (`base`). Por ticket: el texto de búsqueda
   ya unido y en minúsculas, más el título en minúsculas. Se recalcula solo el
   grupo cuya fuente cambió (`_reload` por PRs no tiene que tocar archivos).
2. **Query preparada una sola vez por tecla.** `fuzzyMatch` y `wordHits` pasan a
   recibir la query ya normalizada (y las palabras ya separadas), no a
   recalcularla por elemento. El `RegExp` va a un `static final`. `_boundary`
   compara `codeUnitAt` en vez de crear strings.
3. **Filtrado incremental.** Si la query nueva extiende a la anterior (el caso
   normal al tipear), se filtran solo los matches anteriores. Las dos funciones
   son monótonas al agregar caracteres. `fuzzyMatch` devuelve `null` solo si la
   query no es subsecuencia del path (`_subsequence(p, q, 0)` es la condición
   más débil), y los espacios se ignoran. En `wordHits`, si `"abc"` está en el
   texto, `"ab"` también. Con borrado, pegado o cambio de tab se recalcula desde
   la lista completa, o se guarda una pila de candidatos por prefijo.
4. **Top-k en vez de ordenar todo.** Mantener un heap acotado de tamaño k (5 en
   All, 60 en un tab) y contar los matches aparte para los badges de los tabs
   (`_count`). Armar `SearchResult` solo para los k que se muestran.
5. **Solo los grupos del tab activo.** Para los otros tabs alcanza con el
   contador (si se quiere el badge), que usa el mismo predicado barato sin
   puntuar.
6. Opcional, si con 1–5 sigue habiendo frames largos con 50.000 archivos:
   rankear archivos y tickets como mucho una vez por frame
   (`SchedulerBinding.scheduleFrameCallback`), mientras comandos, worktrees y
   agentes se actualizan al instante. Mover el ranking a un isolate no
   conviene: copiar 50.000 strings en cada tecla cuesta más que lo que ahorra.

**Mejora estimada**

- **Métrica:** tiempo de `_rank()` por tecla y por cada `_reload`, medido en el
  isolate de UI.
- **Alcance:** paleta ⌘K. `rankFiles` y `fuzzyMatch` también los usa ⌘P
  (`quick_open.dart`), que se beneficia de los puntos 1 a 3.
- **Rango:** −70–90 % en workspaces con ≥10.000 archivos o ≥2.000 tickets.
  −40–60 % en workspaces chicos, donde pesan más los costos fijos.
- **Justificación:** con un costo supuesto de ~1–3 µs por path y ~2–5 µs por
  ticket (Dart AOT, con las asignaciones de hoy), 50.000 archivos y 10.000
  tickets dan **~70–200 ms por tecla**, más el sort, contra un presupuesto de
  frame de 16,7 ms (8,3 ms en pantallas de 120 Hz). Con 5.000 archivos y 500
  tickets dan ~6–18 ms, en el borde de perder un frame. Precalcular y preparar
  la query saca las asignaciones por elemento (~30–50 % del costo por
  elemento). El filtrado incremental hace que, desde la segunda o tercera
  letra, se recorra el 1–10 % de la lista. El top-k elimina el sort de hasta
  50.000 elementos.
- **Confianza:** media. El mecanismo se ve en el código. El costo por elemento
  en Dart es un supuesto: cambia con el largo de los paths y la máquina. Si los
  workspaces reales tienen pocos miles de archivos y pocos tickets, la ganancia
  absoluta es chica (unos ms por tecla) aunque el porcentaje se mantenga.

**Consideraciones de seguridad**

Ninguna: todo es local y en memoria, sobre datos que la UI ya tiene.

**Esfuerzo y riesgos**

- Chico–medio: unas 150–250 líneas en `global_search.dart` y `quick_open.dart`,
  más tests.
- Riesgo: que el filtrado incremental deje afuera resultados si se aplica
  cuando la query no extiende a la anterior (borrado, edición en el medio,
  pegado). La condición tiene que ser estricta: `q.startsWith(prev)` y la misma
  versión de la fuente. Conviene un test de propiedad: para queries al azar, el
  ranking incremental y el completo dan lo mismo. También hay que mantener el
  orden exacto de hoy, incluido el desempate por posición (`n`) de
  `rankFuzzy` y `rankText` y por largo y alfabético en `rankFiles`.

---

### P2: abrir ⌘K carga historia de todas las ramas, ramas remotas y PRs que no usa

**Ubicación**

- `kumo-ui/lib/overlays/global_search.dart:236-238` (crea un `EngineRepoActivity` en cada apertura)
- `kumo-ui/lib/overlays/global_search.dart:346-376, 440-447` (`_readLog`, `_readPrs`, `_commits`)
- `kumo-ui/lib/engine/engine_repo_activity.dart:31-46` (el constructor dispara `_load`, `_loadPrs` y `_loadReleases`)
- `kumo-ui/lib/engine/engine_repo_activity.dart:344-373` (`_load`: log de todas las ramas, probe y `ListBranches`)
- `crates/infrastructure/src/git/history.rs:15, 44-94` (`log_all_branches`: un `git log` por rama, hasta `MAX_BRANCHES = 30`)
- `crates/application/src/workspace/service.rs:297-310` (`branches`: toma el lock del workspace)
- `crates/application/src/pulls/service.rs:94-129` (`list`: la caché se consulta antes de pedir, así que dos pedidos simultáneos fallan los dos)

**Cuello de botella actual**

```dart
// global_search.dart: en cada ⌘K con un repo activo
final RepoActivitySource? activity = repo == null ? null
    : (engine == null ? MockRepoActivity(...) : EngineRepoActivity(engine, s.workspace, repo, const []));
```

El constructor de `EngineRepoActivity` está pensado para la vista Git y lanza
tres cargas:

- `_load()`: `Git.Log(main, 30, allBranches: true)` más el probe de
  `ShowCommit` más `Workspace.ListBranches`. En el daemon,
  `log_all_branches` corre `has_head`, `log HEAD`, `symbolic-ref`,
  `rev-parse @{u}`, `for-each-ref` y **un `git log HEAD..<rama>` por cada rama**
  (hasta 30), todos en serie. `ListBranches` suma 2 procesos más y espera el
  lock del `WorkspaceService` (H3 del reporte del 14/11).
- `_loadPrs()`: `PullRequests.List` del repo activo. `_readPrs` de la paleta
  pide **la misma lista** al mismo tiempo, y con la caché fría las dos requests
  salen al host.
- `_loadReleases()`: lo único que la paleta usa siempre.

De todo eso, la paleta usa `releases` y, **solo si `_readLog` falla**,
`commits()` (`global_search.dart:440-447`). Los commits salen de
`_s.changes.log(limit: 300)`, que son 2 procesos. Así, cada ⌘K lanza entre
`7 + B` procesos `git` de más, con B = ramas distintas de HEAD (≤ 30), más un
GraphQL de PRs duplicado. Además, cada `notifyListeners` de la actividad
provoca un `_reload` con un rankeo completo (P1).

**Approach propuesto**

1. Darle a `EngineRepoActivity` un modo liviano, o crear un `ReleasesSource`
   chico, que cargue solo releases y tags:
   `EngineRepoActivity(..., history: false, pullRequests: false)`. Con
   `history: false` no se llama a `_load()` en el constructor. Con
   `pullRequests: false` no se llama a `_loadPrs()`.
2. Si `_readLog` falla (worktree sin log), recién entonces pedir la historia del
   repo como respaldo, con `activity.loadHistory()` explícito.
3. Para los PRs, la paleta ya tiene `_readPrs`, que cubre el repo activo. No
   hace falta otra fuente.
4. Opcional, en el daemon: hacer *single-flight* en `PullRequestService::list`
   (un `HashMap<PathBuf, Shared<Future>>` de pedidos en vuelo) para que dos
   pedidos simultáneos del mismo repo compartan la respuesta. Le sirve también
   a la vista Git.

**Mejora estimada**

- **Métrica:** procesos `git` y llamadas al host por apertura de la paleta.
- **Alcance:** cada ⌘K con un repo activo. Es una acción frecuente, varias
  veces por hora.
- **Rango:** procesos `git` −80–95 % por apertura: de `2 + 7 + B` a 2. Con
  B = 10 pasa de 19 a 2, y con B = 30, de 39 a 2. Una llamada GraphQL menos por
  apertura con la caché fría (más de 60 s desde la anterior), y 2 `_reload`
  menos (de los ~6 que hay al abrir).
- **Justificación:** los procesos que se eliminan corren en serie en el pool
  bloqueante del daemon. Con ~3–8 ms por proceso en macOS (supuesto del
  reporte del 14/11), son ~50–300 ms de CPU y de I/O por apertura, más lo que
  tarde cada `log HEAD..<rama>` en repos con mucha historia. La UI no espera
  esos procesos para mostrar la paleta, pero compiten con las demás RPC de git
  y con el lock del workspace.
- **Confianza:** alta en el mecanismo. Media en la magnitud, que depende de
  cuántas ramas tenga el repo activo y de la frecuencia de ⌘K.

**Consideraciones de seguridad**

- El single-flight del punto 4 tiene que usar como clave el repo **y el
  perfil**. Hoy `PullRequestService` es por perfil (`profiles.rs:228`), así que
  alcanza con mantenerlo dentro del servicio y no subirlo a un nivel global.
  Así no se comparte una respuesta entre perfiles con tokens distintos.

**Esfuerzo y riesgos**

- Chico: unas 20–40 líneas en `engine_repo_activity.dart` y
  `global_search.dart`. El punto 4 es otro cambio chico en `pulls/service.rs`.
- Riesgo: que un repo sin log en el worktree deje de mostrar commits si el
  respaldo del punto 2 no se dispara. Hay que cubrirlo con un test de la
  paleta con un `MockRepoActivity` cuyo log falle.

---

### P3: chequeo de merges de TODOs siempre activo, en serie y sin caché

**Ubicación**

- `kumo-ui/lib/views/todos_view.dart:44-55` (timer de 1 min, arrancado en `initState`)
- `kumo-ui/lib/views/tasks_screen.dart:256-264` y `kumo-ui/lib/shell/app_shell.dart:117-128` (`TasksScreen` vive siempre en el `IndexedStack`, y monta `TodosView` mientras la vista elegida sea "todos")
- `kumo-ui/lib/app/app_state.dart:1744-1757` (`checkTodoMerges`: un `forBranch(refresh: true)` por TODO, en serie)
- `crates/application/src/pulls/service.rs:132-165` (`for_branch`), `279-295` (`worktree`: `canonicalize` por cada worktree), `334-357` (`branch_target`), `385-398` (`host_token`)
- `crates/infrastructure/src/git/branch.rs:10-25` (4 procesos `git`: `rev-parse --git-dir`, `symbolic-ref`, `rev-parse @{u}`, `rev-list --count HEAD --not --remotes`)
- `crates/infrastructure/src/ci/github_pulls.rs:15-22, 104-131` (query con `FIELDS` completo para hasta 5 PRs)
- `crates/daemon/src/profiles.rs:240` (caché de PRs de 60 s, igual al intervalo del timer)

**Cuello de botella actual**

```dart
// todos_view.dart
// Pull requests merge on the host: look every minute while this is open.
_merges = Timer.periodic(const Duration(minutes: 1), (_) => s.checkTodoMerges().ignore());

// app_state.dart
for (final todo in todos.todos.where((t) => t.status == TodoStatus.pr && !t.done)) {
  final branch = await pullRequests.forBranch(run.worktreePath, refresh: true);   // en serie
  ...
}
```

1. **Corre aunque no se vea.** `TasksScreen` está siempre montada en el
   `IndexedStack` de `AppShell`. Si el usuario dejó Tasks en "TODOs" y se fue a
   Terminal, `TodosView` sigue montado y el timer sigue corriendo cada minuto
   mientras la app esté abierta. El comentario dice "while this is open", pero
   no es lo que pasa. `GitScreen` resuelve el mismo caso a propósito
   (`git_screen.dart:104-114`: "offstage it shouldn't poll CI").
2. **Saltea la caché.** `refresh: true` ignora la caché de 60 s. Igual, con un
   timer de 60 s la caché ya estaría vencida casi siempre.
3. **Por cada TODO en estado PR, en serie:** busca el worktree con
   `canonicalize` de cada worktree del workspace, lanza 4 procesos `git` (el
   `rev-list --not --remotes` recorre la historia local), lee el token del
   llavero o de `gh`, y hace una query GraphQL que trae hasta 5 PRs con
   reviewers, reviews, 100 review threads y 100 checks cada uno. Para saber si
   se mergeó alcanza con `state`.
4. **El dato necesario ya está guardado.** `TodoRun` guarda `pr_number` y
   `pr_url` (`crates/domain/src/todos/todo.rs:131-132`). No hace falta
   resolver la rama ni correr `git`.

Con N TODOs en PR, el costo es `60 × N` ciclos por hora (4 procesos `git` +
lectura de token + 1 request HTTPS de ~0,3–0,8 s), durante todo el día. Es
pesado en red, batería y cuota de la API, aunque no se note en la UI.

**Approach propuesto**

1. **Gating por visibilidad (chico, primero).** Arrancar y parar el timer según
   `s.view == KumoView.tasks` y la vista "todos", con el mismo patrón que
   `GitScreen._bind`. Al volver a la vista, chequear una vez enseguida. Opcional:
   pausar también con la ventana en segundo plano
   (`AppLifecycleListener`).
2. **Consulta en lote por número de PR (medio).** Una RPC nueva, por ejemplo
   `PullRequests.States(repo_path, numbers[])`, que agrupe por repo los TODOs en
   PR y haga **una** request por repo:
   - GitHub: una query GraphQL con alias y variables:
     `query($owner:String!,$name:String!,$n0:Int!,$n1:Int!){ repository(owner:$owner,name:$name){ p0: pullRequest(number:$n0){ state mergedAt } p1: pullRequest(number:$n1){ state mergedAt } } }`.
   - GitLab y Bitbucket: un GET por PR, liviano y por id. Sigue sin `git`.
   - Sin `BranchReader::read`: la RPC no mira el worktree.
3. **En la UI:** `checkTodoMerges` agrupa los TODOs por `run.repoPath` y llama a
   la RPC por repo, en paralelo con un tope chico (por ejemplo 3).
4. Opcional: backoff para PRs viejos. Cada 1 min durante la primera hora,
   después cada 5 min.

**Mejora estimada**

- **Métrica:** requests al host y procesos `git` por hora dedicados a detectar
  merges de TODOs.
- **Alcance:** UI y daemon, con al menos un TODO en estado PR.
- **Rango:**
  - Solo con el punto 1: −70–95 % de los ciclos, según cuánto del día el
    usuario pasa fuera de la vista TODOs (en una app de terminal y agentes,
    supongo que la mayor parte).
  - Con los puntos 1 y 2: −90–99 % de las requests (de N a R por chequeo, con
    R = repos con TODOs en PR, más el gating) y −100 % de los procesos `git` de
    este flujo. Con N = 6 TODOs en 2 repos: hoy son ~360 requests y ~1.440
    procesos `git` por hora. Con los dos cambios y la vista abierta 1 h por
    día: ~120 requests en ese rato y 0 procesos `git`.
- **Justificación:** el número de ciclos pasa de "minutos con la app abierta
  × N" a "minutos con la vista visible × R".
- **Confianza:** alta en el mecanismo (se ve en `IndexedStack` + `Timer`). Media
  en la magnitud, que depende de cuántos TODOs queden en PR y por cuánto tiempo.

**Consideraciones de seguridad**

- La RPC nueva tiene que validar que `repo_path` sea un repo del workspace del
  perfil del llamador (`repo_at` + `services_of`), como `list`, y usar el token
  de ese host, sin loguearlo.
- Los números de PR van como **variables** de GraphQL (`$n0`, `$n1`…). Solo los
  alias (`p0`, `p1`…) se generan en el texto de la query, a partir de índices,
  nunca de datos de la request. Validar `number > 0` y poner un tope (por
  ejemplo 50 por llamada).
- Con el gating, la autolimpieza (`todos.autoClean`) pasa a correr al volver a
  la vista y no en segundo plano. Es lo que dice el comentario actual, pero
  conviene confirmarlo con producto.

**Esfuerzo y riesgos**

- Punto 1: chico (unas 20 líneas en `todos_view.dart`). Punto 2: medio (proto,
  servicio, los tres clientes, mapping, UI y tests con
  `infrastructure/src/test_server.rs`).
- Riesgo: un PR recreado con otro número (cerrado y abierto de nuevo) no se
  vería por número. Hoy `for_branch` lo encuentra por rama. Mitigación: si el
  estado por número es `CLOSED` sin merge, caer una vez a `for_branch` para esa
  rama.

---

### P4: filas de la paleta, un `TextSpan` por carácter y remedición en cada hover

**Ubicación**

- `kumo-ui/lib/overlays/global_search.dart:869-872` (`_spans`: un `TextSpan` por carácter del título)
- `kumo-ui/lib/overlays/global_search.dart:882-887, 889-920` (`widthOf` con `TextPainter` en cada build, y búsqueda binaria con más layouts)
- `kumo-ui/lib/overlays/global_search.dart:822-826` (`onHover` → `setState` de toda la paleta)

**Cuello de botella actual**

```dart
TextSpan _spans(int from, [int? to]) => TextSpan(children: [
  if (from > 0) TextSpan(text: _ellipsis, style: style),
  for (var k = from; k < (to ?? title.length); k++) TextSpan(text: title[k], style: hits.contains(k) ? strong : style),
]);
```

Cada `MatchLine` arma un `TextSpan` por letra: un asunto de commit de 70
caracteres son 70 spans. En cada build mide el título y el detalle con un
`TextPainter` nuevo. Si el título no entra, hace una búsqueda binaria con más
layouts (~log₂ de la posición del primer match) y al final otro layout para el
`Text.rich`. Pasar el mouse de una fila a otra llama a `setState` en
`_GlobalSearchState`, que reconstruye la lista entera. Todas las filas visibles
y las del cache extent (~15–20) se vuelven a medir, aunque solo cambiaron dos.
Lo mismo pasa en cada tecla, encima del costo de P1.

**Approach propuesto**

1. **Spans por tramo, no por carácter:** agrupar caracteres consecutivos con el
   mismo estilo (match o no). Un título con 4 letras que coinciden pasa de ~70
   spans a ≤ 9.
2. **Cachear las medidas:** guardar `titleW` y `detailW` por
   `(title, detail, estilo, textScaler)` en el `State` de la fila (o en un LRU
   chico a nivel de la paleta) y recalcular la búsqueda binaria solo si cambian
   el ancho disponible o los hits.
3. **Hover sin reconstruir todo:** guardar `_selected` en un
   `ValueNotifier<int>` y que cada fila escuche solo si ella está seleccionada
   (`ValueListenableBuilder` o `select`). Así un hover reconstruye dos filas.

**Mejora estimada**

- **Métrica:** tiempo de build y layout de la lista por cambio de hover y por
  tecla (hilo de UI, en DevTools).
- **Alcance:** la paleta ⌘K.
- **Rango:** −60–85 %.
- **Justificación:** el costo de armar un párrafo crece con la cantidad de
  spans (push y pop de estilo por span). Reducirlos ~8× y cachear las medidas
  saca la mayor parte de los 3–10 layouts por fila. El punto 3 baja de ~15–20
  filas a 2 por hover.
- **Confianza:** baja–media. No hay medición. Depende del largo de los títulos y
  de cuántas filas quedan cortadas (las cortadas son las que hacen la búsqueda
  binaria).

**Consideraciones de seguridad**

Ninguna.

**Esfuerzo y riesgos**

- Chico: unas 40–80 líneas en `global_search.dart`.
- Riesgo: que cambie el render del corte con "…" (el comentario de
  `MatchLine` detalla casos sutiles de medida). Hay que mantener los tests de
  widget de la paleta y sumar uno con títulos largos y matches al final.

---

## Cómo validar

1. **Ranking de la paleta (P1).**
   - Envolver `_rank()` en `Timeline.startSync('palette.rank')` /
     `finishSync()` y medir en un build Profile (`flutter run --profile`, que el
     repo ya usa: `kumo-ui/build/macos/Build/Products/Profile`) con Flutter
     DevTools → Performance.
   - Escenario: un repo sintético con 50.000 archivos trackeados y una fuente de
     10.000 tareas (la del escenario `kumo-bench tasks`). Tipear `src/handler`
     letra por letra y registrar p50/p95 de `palette.rank` y los frames de más
     de 16 ms, antes y después.
   - Microbenchmark complementario en `flutter test`: `rankFiles` sobre 50.000
     paths sintéticos con `Stopwatch`. Es JIT, así que sirve solo para comparar
     antes contra después, no como número absoluto.
2. **Procesos al abrir ⌘K (P2).** Arrancar `kumod` con
   `GIT_TRACE2_EVENT=/tmp/trace.json`, o con un wrapper `git` primero en el
   `PATH`, y contar los eventos `start` por cada apertura de la paleta, en un
   repo con unas 20 ramas remotas. Con `RUST_LOG` al nivel del servicio de PRs,
   contar las llamadas a `PullRequests.List` por apertura con la caché fría.
3. **Merges de TODOs (P3).** Con 3 TODOs en estado PR, dejar Tasks en "TODOs",
   cambiar a Terminal y contar durante 10 minutos las RPC `ForBranch` (log del
   daemon) y los procesos `git`. Hoy deberían ser ~30 RPC y ~120 procesos.
   Después del cambio, 0. Volver a la vista y verificar que el chequeo corra una
   vez enseguida.
4. **Filas de la paleta (P4).** DevTools → "Track widget builds" y la duración
   del frame en el hilo de UI mientras el mouse recorre filas con títulos
   largos (commits con asuntos largos, paths profundos), antes y después.

## Limitaciones

- **Análisis estático.** No ejecuté nada. Los costos por elemento en Dart
  (~1–3 µs por path, ~2–5 µs por ticket), el costo por proceso `git` (~3–8 ms)
  y la latencia de GraphQL (~0,3–0,8 s) son supuestos típicos, no medidos.
- **Alcance reconstruido sin diff.** No tuve shell para correr
  `git diff v0.8.3...release/0.9.0`. Identifiqué la release por los merges del
  reflog de `origin/release/0.9.0` (#102, #101 y #104) y por el código que
  referencia los módulos nuevos (TODOs, paleta, skills). Si esos PRs cambiaron
  otros archivos existentes de forma no evidente, pueden haber quedado afuera.
- **#101 `fix/windows-traffic-lights`:** no lo revisé. Por lo que indica el
  nombre (botones de ventana en Windows) no espero impacto en performance, pero
  no está verificado.
- **Revisado y descartado por impacto despreciable:**
  - `TodoService` publica la lista completa en cada cambio y la UI la
    decodifica entera. Con decenas o cientos de TODOs y cambios esporádicos (un
    paso de estado), el costo es chico. No es comparable con H5 del reporte del
    14/11: los TODOs no llevan eventos.
  - `SqliteTodoStore`: un upsert de una fila por cambio, `busy_timeout`
    configurado y lectura completa solo al arrancar.
  - `AgentDefService::capabilities` (selector de skills): recorre carpetas y lee
    hasta 16 KB por `SKILL.md`. Corre solo en `load()` de la lista de agentes.
  - `skill_picker.dart`: filtra decenas o cientos de skills y usa
    `ListView.builder`.
  - `TodosView`: el `setState` por tecla del composer reconstruye el tablero.
    Con decenas de TODOs son fracciones de ms.
  - `Docs.List` desde la paleta: ya tiene debounce de 250 ms, caché de 60 s por
    query y fuentes en paralelo (`docs/service.rs:73-121`).
- **Fuera de alcance:** los hallazgos H1–H7 del reporte del 14/11 no son parte
  de esta release, y no verifiqué si siguen abiertos. H3 (el lock del
  workspace) afecta a P2 (`ListBranches` lo espera), y el `canonicalize` por
  worktree que menciona aparece también en `PullRequestService::worktree` (P3).
- **Observación que no es de performance:** `TodoService` hace
  leer-modificar-escribir sin exclusión (`get` → modifica → `save`,
  `application/src/todos/service.rs:192-210`). Dos cambios simultáneos sobre el
  mismo TODO pueden perder uno, por ejemplo el `kumod todo testing` de un
  agente mientras el usuario aprieta "Stop". También pueden quedar la base y la
  memoria en órdenes distintos (A guarda, B guarda, B publica, A publica). Un
  `tokio::sync::Mutex` del servicio que cubra el `get` y el `save` lo resuelve
  sin costo apreciable, porque los cambios son esporádicos.
