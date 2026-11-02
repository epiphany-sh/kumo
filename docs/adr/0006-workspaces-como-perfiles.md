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
  `GIT_AUTHOR_*`: así rebase, cherry-pick y amend conservan al autor original
  (un test lo verifica con `commit --amend`). Se aplica donde se commitea
  (Kumo, shells, agentes), no al pushear. Va por encima del `user.*` del
  repo, sin tocarlo.
- **Un solo armado** (`GitSetup`, en el dominio) produce las variables de un
  perfil: `GIT_CONFIG_*`, `GIT_SSH_COMMAND`, `GH_TOKEN` /
  `GH_ENTERPRISE_TOKEN` y `KUMO_PROFILE`. Lo recalcula `GitEnvironment` cuando
  cambia el perfil, los hosts de sus remotes o una credencial, y lo leen el
  git de Kumo y las terminales del perfil (agentes incluidos). El perfil por
  defecto sin configurar no agrega nada.
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
  `kumod git-credential`, un helper único para todos los hosts (antes se
  vacía la lista de helpers del host, así no se ofrece el del usuario). El
  helper le pide el token al daemon (`Profiles.GitCredential`), que solo
  contesta para hosts de los remotes del perfil y nunca lo loguea. Usuario por
  proveedor: GitHub `x-access-token`, GitLab `oauth2`, Bitbucket
  `x-bitbucket-api-token-auth`. Un perfil que no es el por defecto y no tiene
  nada configurado muestra un aviso.
- **Un token pegado en el perfil por defecto no cambia su git**: antes de los
  perfiles esos tokens eran solo para pipelines (scopes de lectura), y
  reescribir sus remotes rompería pushes que hoy andan. En el perfil por
  defecto solo cuenta una cuenta de `gh` elegida a propósito.
- **Firma opcional** con la misma clave SSH (`gpg.format=ssh`).

### Agentes

Cada CLI recibe su variable de carpeta apuntando a `profiles/<id>/cli/<cli>/`
(creada antes de arrancar, en `start` y en `login`), solo si se verificó que
su credencial queda separada. Si la guardara en un ítem del llavero que no
depende de la carpeta, loguearse desde un workspace pisaría el login del
usuario también en su terminal. El resultado queda en `CLI_HOMES`
(`kumo-domain`):

| CLI | Variable | Verificado | Resultado |
|---|---|---|---|
| Claude Code | `CLAUDE_CONFIG_DIR` | 2.1.316 | ítem `Claude Code-credentials-<sha256(dir)[..8]>`, aparte del de siempre; con carpeta nueva `auth status` da deslogueado |
| Codex CLI | `CODEX_HOME` | 0.157.0 | `auth.json` en la carpeta (`cli_auth_credentials_store` es `file` por defecto); con carpeta nueva `login status` da deslogueado |
| Gemini CLI | `GEMINI_CLI_HOME` | no | sin verificar: comparte el login de la Mac |
| Copilot CLI | `COPILOT_HOME` | no | sin verificar: comparte el login de la Mac |
| Agentes propios | — | — | comparten el login de la Mac |

`AgentProvider.own_sign_in` le dice a la UI cuáles tienen login propio en el
workspace. El perfil por defecto no setea ninguna variable. El uso de plan se
lee de la carpeta de cada perfil: el status line de Claude Code lee el
`settings.json` de su `CLAUDE_CONFIG_DIR` y los rollouts de Codex su
`CODEX_HOME`.

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
