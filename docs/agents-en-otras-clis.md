# Your agents en otras CLIs

Un agente es **una sola definición**: el `.md` de siempre, en
`.claude/agents/`. La IA se elige **al correrlo**, y cada CLI lo traduce a lo
suyo. Así, quien se queda sin tokens en una IA sigue en otra sin recrear nada.

## Reglas

- **Traducir nunca da más permisos que el original.** Si una restricción no se
  puede replicar en esa IA, Run avisa o no arranca. `bypassPermissions` no se
  traduce.
- **Solo los Connectors declarados.** En Codex y Copilot el agente no hereda
  los MCP ni las skills del usuario, y computer use nunca se hereda sin
  pedirlo. En Codex tampoco los plugins; en Copilot, ver "Sin confirmar".
- **Sin límites por defecto.** Tiempo y créditos son opcionales en Codex y
  Copilot: cortar una tarea por un número estimado puede costar más que dejarla
  terminar. Se muestra el consumo en vivo y Stop queda a mano.
- **Cada CLI en su archivo**, en `crates/domain/src/agent_defs/cli/`, detrás del
  trait `AgentCli`. Un cambio en una no alcanza a las otras.

## Cuando se termina el plan

Lo decide `kumo-ui/lib/data/plan_limits.dart`, con dos señales:

- **El uso que Kumo ya lee** (Claude Code y Codex): una ventana sin nada que
  le quede y que todavía no se renovó. Es la señal firme.
- **Lo que dijo la CLI al parar**: el error de una corrida de prueba, o la
  última línea de una terminal que ya no trabaja ("usage limit", "hit your
  limit", "premium requests", "AI credits"…). Es lo único que hay para
  Copilot, que no informa su uso.

Lo que hace Kumo con eso:

- **Run y el playground arrancan en una CLI con plan.** La agotada figura como
  `out` en "Runs with" y no se elige por defecto. Si la elegís igual, Run dice
  cuándo se renueva y ofrece usar otra.
- **Una terminal que se quedó sin plan ofrece "Go on with …".** Arranca el
  mismo agente en la otra CLI, en la misma carpeta y con el mismo primer
  mensaje, más una nota para que revise lo que ya está hecho. La conversación
  no pasa de una IA a otra; los cambios en la carpeta sí.
- **Una corrida de prueba que falló por el límite ofrece "Try it on …"**, con
  la misma tarea y la misma versión del agente.

Nunca cambia de CLI sola: siempre lo ofrece.

## Codex: cómo se traduce

Lo arma `crates/domain/src/agent_defs/cli/codex.rs` desde el JSON que la UI
manda en cada corrida (`agentInlineJson`). La UI muestra lo mismo antes de
arrancar (`agentCliNotes`).

| Del agente | En Codex |
|---|---|
| Instrucciones | `-c developer_instructions="…"`, como string TOML, con `role_sentence` al final |
| Sin `Edit`, `Write` ni `Bash`, o en `plan` | `-s read-only`: lee y corre comandos, pero no cambia nada ni sale a la red |
| `Edit` o `Write` sin `Bash` | `-s workspace-write`, sin carpetas temporales |
| `Bash` (o sin línea `tools`) | `-s workspace-write`, con temporales |
| Aprobaciones | `on-request` solo con `Bash` en una terminal (no en `plan` ni `dontAsk`); si no, `never`. Headless, siempre `never` |
| `bypassPermissions` | No se traduce: queda como el modo por defecto |
| `haiku`, `sonnet`, `opus` | El modelo de Codex del usuario, con esfuerzo `low`, `medium` o `high` |
| Otro modelo que no sea de Claude | `-m <modelo>` |
| `WebSearch` | `web_search="live"`; si no, `"disabled"` |
| Siempre | `mcp_servers={}`, `features.apps=false`, `features.plugins=false`, `skills.include_instructions=false` |
| Contexto de la corrida | Se nombra en el primer mensaje; nunca `--add-dir`, que daría escritura |
| Connectors, skills, `maxTurns`, `memory`, tope de costo | No pasan: Run lo avisa |

`--ignore-user-config` sería más simple, pero solo lo acepta `codex exec`: la
terminal interactiva lo rechaza. Y la política `untrusted` ya no existe en
0.157.0; quedan `on-request` y `never`.

Probado con el `codex` real (`crates/daemon/tests/real_clis.rs`): un agente de
solo lectura contesta, no puede escribir aunque se lo pidan, y su sesión en la
terminal arranca y sigue viva.

## Copilot: cómo se traduce

Copilot solo lee agentes de archivos. Para cada corrida, Kumo escribe el agente
en `agent-files/<nombre>-<12 hex>/.github/agents/` adentro de la carpeta del
perfil, y lo arranca con `--agent <nombre>-<12 hex> --add-dir <esa carpeta>`.
Lo arma `crates/domain/src/agent_defs/cli/copilot.rs`, y la UI muestra lo mismo
antes de arrancar (`agentCliNotes`).

El nombre lleva una parte al azar porque Copilot también lee los agentes del
repo (`.github/agents/` y `.claude/agents/`) y, si se llaman igual, prefiere el
del repo: un repo clonado podría reemplazar tu agente por uno con más
herramientas. Las copias de las corridas de prueba se borran al terminar y las
de las terminales a los 7 días, como `runs/`.

| Del agente | En Copilot |
|---|---|
| Instrucciones | El cuerpo del archivo, con `role_sentence` al final |
| Descripción, nombre, tools | La frontmatter, con los valores en JSON para que la descripción no pueda agregar campos |
| `Read` | `read` |
| `Grep`, `Glob` | `search` |
| `Edit`, `Write`, `MultiEdit`, `NotebookEdit` | `edit` |
| `Bash` | `execute` |
| `WebFetch`, `WebSearch` | `web` |
| Sin línea `tools` | Las herramientas propias de Copilot (`read`, `search`, `edit`, `execute`, `web`, `todo`), nunca las MCP del usuario |
| `plan` | Saca `edit` y `execute` |
| `acceptEdits` | `--allow-tool=write`. En el resto de los modos no se aprueba nada por adelantado: la terminal pregunta y la corrida de prueba lo deniega |
| `bypassPermissions`, `dontAsk` | No se traducen: pregunta |
| `haiku`, `sonnet`, `opus`, `inherit` | El modelo de Copilot del usuario. `--reasoning-effort` no va: con `auto` Copilot lo rechaza |
| Otro modelo que no sea de Claude | `--model <modelo>` |
| Siempre | `--disable-builtin-mcps` y `--excluded-tools=skill` |
| Contexto de la corrida | `--add-dir <carpeta>`, la copia de Kumo; se nombra en el archivo y en el primer mensaje |
| Primer mensaje | `--interactive=<texto>`, pegado al flag para que un texto que empieza con `-` siga siendo el texto |
| Corrida de prueba | `--prompt=<tarea> … --no-ask-user --output-format json` |
| Connectors, skills, `Task`, `maxTurns`, `memory`, tope de costo | No pasan: Run lo avisa |

`--trust-folder` no va: carga los hooks, MCP y plugins del repo. Sin él, la
corrida de prueba funciona igual en una carpeta que Copilot no conoce; la
terminal pregunta si confiar en ella y se contesta ahí.

Las terminales de Copilot dicen su estado con `OSC 7501`, sin flags: `blocked`
es que pregunta algo, `working` que trabaja, `idle` y `done` que terminó su
turno. Kumo lo lee en todas las sesiones de Copilot, no solo en los agentes
(`ActivityTracker`).

Probado con el `copilot` real (`crates/daemon/tests/real_clis.rs`):

- Un agente del repo con el mismo nombre no lo reemplaza.
- Un agente de solo lectura no puede escribir, ni con una herramienta de
  archivos ni con un comando.
- Una tarea que empieza con `-` llega como tarea.
- La sesión en la terminal arranca y sigue viva.

A mano: `--allow-tool=write` deja crear el archivo y `--excluded-tools=skill`
saca `skill` de las herramientas.

## Qué se probó

Con Codex CLI 0.157.0 y GitHub Copilot CLI 1.0.107, en un repo descartable.

| | Copilot | Codex |
|---|---|---|
| Arrancar como agente | `--agent`, con `-i` y `-p` | No hay flag: `-c developer_instructions=…` |
| Bloquear escritura | La línea `tools` frena aun con `--allow-all-tools` | `-s read-only`: lo frena el sistema operativo |
| Dar edición | `Edit`/`Write` crean archivos; en `-p` también hace falta `--allow-tool=write` | `-s workspace-write`; también deja escribir en `/tmp` |
| Archivo de Claude | Lo carga tal cual; ignora `permissionMode`, `maxTurns`, `memory`, `color` con un aviso | Lo traduce Kumo |
| Contexto fuera del repo | `--add-dir` da lectura y carga agentes; sin eso, en `-p` se deniega | Lo lee sin `--add-dir`, que además daría escritura |
| Modelo desconocido (`sonnet`) | Exit 1 | Exit 1, con `turn.failed` |
| Salida headless | `-p --output-format json` | `exec --json` |
| Consumo | `result.usage`, `session.usage_checkpoint`, `--usage-output-file` | Tokens en `turn.completed`; sin costo |
| Tope de gasto | `--max-ai-credits` (mínimo 30, tope blando) | No encontrado |
| Estado en la terminal | `OSC 7501`: `working`, `idle`, `done`, `blocked:kind=permission` | Título con `Action Required` |

## Cosas a tener en cuenta

- **El agente hereda el entorno.** Codex sin shell (`features.shell_tool=false`)
  intentó correr un comando con el MCP de computer use del usuario. Con
  `features.apps=false` y `features.plugins=false` esa herramienta dejó de
  figurar entre las que dice tener.
- **El foco depende del modelo.** La selección automática de Copilot cambia de
  modelo entre corridas. `mai-code-1.1-flash` salió del rol las dos veces que le
  tocó, aun con `role_sentence`, y una vez hizo 29 llamadas a herramientas para
  contestar "Go."; `gpt-6-luna` lo respetó las dos. Muestra chica, pero alcanza
  para avisar: Run sugiere fijar un modelo con `/model` en Copilot.
- **Copilot aprueba solo algunos comandos.** En `-p`, sin `--allow-tool`, corrió
  `echo` y `ls` en la carpeta y denegó escrituras y comandos fuera de ella.
- **Copilot no tiene límite de turnos.** Un agente de solo lectura con una tarea
  imposible hizo unas 30 llamadas a tools.
- **Primera vez en una carpeta.** En modo interactivo Copilot muestra "Confirm
  folder trust"; `--trust-folder` solo sirve para `-p`.
- **Fuera de un repo.** `codex exec` necesita `--skip-git-repo-check`.
- **Modelos.** Los alias de Claude rompen la corrida en las otras CLIs: siempre
  se mapean.

## Sin confirmar

- `sql` sigue disponible en Copilot: es su base de la sesión (lista de tareas),
  no toca archivos del repo.
- Los plugins que el usuario instaló en Copilot: no hay flag para dejarlos
  afuera. Sus skills no llegan (`--excluded-tools=skill`) y sus herramientas
  no están en la línea `tools`, pero falta ver si traen hooks.
- Copilot instalado con npm en Windows arranca por `copilot.cmd`: un primer
  mensaje con `&`, `|`, `%` o saltos de línea no pasa por `cmd.exe` y Run lo
  rechaza con un aviso. El ejecutable nativo no tiene ese límite.
- `skills.include_instructions=false` de Codex: bajó de 91k a 25k tokens, en una
  sola corrida.
- Las listas de herramientas son lo que informó cada modelo, no una inspección
  directa. Con la traducción de Codex le quedan `image_gen` y las de "goals":
  no tocan archivos, pero generar imágenes gasta cuota.
- Codex en una carpeta que todavía no aprobó: la terminal puede preguntar si
  confiar en ella. Es su propia pregunta y se contesta ahí.
- `COPILOT_HOME`: una carpeta nueva queda sin sesión, pero falta probar que
  iniciar sesión ahí no pise el login del usuario. Hasta entonces Copilot sigue
  compartiendo el login entre workspaces (`crates/domain/src/agents/homes.rs`).
- Retomar una corrida cortada con `copilot --resume` y `codex exec resume`.
