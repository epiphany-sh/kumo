# ADR-0006 — Workspaces: un perfil aislado por empresa o cliente

- Estado: aceptada
- Fecha: 2026-10-31

## Contexto

La UI suma **workspaces** arriba de todo: uno por empresa, cliente o proyectos
propios ("Workspace 1", "Workspace 2"). El punto es el aislamiento completo:
cambiar de workspace cambia los hosts git y sus tokens, las fuentes de tareas,
las bases de conocimiento, los namespaces, los agentes (con sus logins y su
uso de plan), la identidad de git y las carpetas de worktrees. Tema, layout,
fuente de la terminal, atajos y actualizaciones siguen siendo de toda la app.

Los agentes y terminales del workspace que se deja **siguen corriendo**, y un
workspace se puede abrir en otra ventana a la vez.

## Decisión

### Nombre

En el motor se llaman **perfiles** (`ProfileId`, `service Profiles`, header
`kumo-profile`, carpeta `profiles/<id>/`), porque `Workspace` ya es el servicio
de namespaces, repos y worktrees. La UI los llama "workspace".

### Un daemon, una carpeta de datos por perfil

El aislamiento sale de la construcción, no de filtrar:

- **Registro** en `<data>/profiles.json`: id (slug estable, renombrar no lo
  cambia), nombre, color, posición, carpeta de worktrees e identidad de git.
- **El perfil por defecto son los datos de siempre**, en el mismo lugar:
  `<data>/kumo.db` y `<data>/agents/`. Los nuevos viven en
  `<data>/profiles/<id>/`. No hay migración de archivos, y un downgrade sigue
  andando porque las versiones viejas no mandan el header y leen `kumo.db`.
- **Un bundle de servicios por perfil** (`ProfileServices`: workspace, git,
  tareas, docs, pipelines, PRs, agentes, tests, y el fallback de `gh`), armado
  la primera vez que una llamada lo nombra y vivo hasta que se borra el perfil.
  Así los agentes de un perfil que se dejó siguen corriendo.
- **Ruteo por header**: toda llamada salvo `Core` y `Profiles` lee
  `kumo-profile`. Sin header va al perfil por defecto (UIs viejas); un id
  desconocido es `NOT_FOUND` "unknown workspace". Un `Watch` queda atado al
  perfil con el que arrancó.
- **Terminales globales** (son procesos), pero cada una anota su perfil:
  `List` filtra por header y `Attach` rechaza las de otro.
- **Borrar** frena sus agentes y terminales y borra su carpeta y sus entradas
  del llavero; nunca toca repos ni worktrees en disco. Se rechaza para el
  perfil por defecto, el último, y uno que una ventana está mostrando (lo
  sabemos por los `Profiles.Watch` abiertos con ese header).

### Nada cambia fuera de Kumo

Todo lo que es por perfil llega a los procesos por variables de entorno en
las shells, agentes y comandos git que lanza Kumo. Kumo nunca escribe
`~/.gitconfig`, `.git/config`, `~/.ssh/config` ni `~/.config/gh`. El perfil por
defecto sin configurar no agrega ninguna variable.

### Secretos

El perfil por defecto mantiene los nombres actuales del llavero
(`task-source:<id>`, `host-token:<host>`); los demás los prefijan
(`<perfil>/host-token:<host>`). El `SecretStore` de cada perfil trae el
prefijo adentro, así un servicio no puede agarrar el de otro.

### Git

- **Identidad** (`user.name` / `user.email`) por `GIT_CONFIG_COUNT`, no con
  `GIT_AUTHOR_*`: así rebase, cherry-pick y amend conservan al autor original.
  Se aplica donde se commitea (Kumo, shells, agentes), no al pushear.
- **Cuentas de GitHub con `gh` multi-cuenta**: el perfil fija una cuenta por
  host y Kumo pide siempre `gh auth token --user <cuenta>`, sin depender de la
  cuenta activa. `GH_CONFIG_DIR` por perfil no sirve: el token activo de gh es
  un único ítem del llavero (`gh:<host>`, cuenta vacía) para toda la máquina.
  Iniciar sesión con gh restaura después la cuenta activa que había.
- **Qué credencial usa cada remote**:

  | El perfil tiene | Remotes SSH | Remotes HTTPS |
  |---|---|---|
  | clave SSH | por SSH con esa clave (`IdentitiesOnly`) | token del perfil |
  | cuenta o token, sin clave | reescritos a HTTPS, token del perfil | token del perfil |
  | nada | como hoy | como hoy |

  La reescritura es `url.<https>.insteadOf` por env, y el token lo da
  `kumod git-credential`, un helper único para todos los hosts. Un perfil que
  no es el por defecto y no tiene nada configurado muestra un aviso.
- **Firma opcional** con la misma clave SSH (`gpg.format=ssh`).

### Agentes

Cada CLI recibe su variable de carpeta (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`,
`GEMINI_CLI_HOME`, `COPILOT_HOME`) apuntando a `profiles/<id>/cli/<cli>/`. Antes
de ofrecer login por perfil en un CLI se verifica que su credencial quede
separada; si la guarda en un ítem del llavero que no depende de la carpeta,
ese CLI comparte el login de la máquina y la UI lo dice. El uso de plan se lee
de la carpeta de cada perfil.

## Consecuencias

- Un perfil nunca ve datos de otro: cada servicio solo tiene sus propios stores.
- Los perfiles abiertos quedan vivos hasta borrarlos (memoria y tareas de fondo
  por perfil usado en la sesión).
- Se entrega en PRs apilados: base de perfiles y ruteo; secretos y terminales;
  git; agentes. Cada uno deja la app andando sin la UI nueva.

## Fuera de alcance

Mover o compartir cosas entre workspaces; aplicar la config de git de un
workspace fuera de Kumo; una clave SSH por host; multi-cuenta para `glab` o
Bitbucket.
