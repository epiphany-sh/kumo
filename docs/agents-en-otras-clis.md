# Your agents en otras CLIs

Un agente es **una sola definición**: el `.md` de siempre, en
`.claude/agents/`. La IA se elige **al correrlo**, y cada CLI lo traduce a lo
suyo. Así, quien se queda sin tokens en una IA sigue en otra sin recrear nada.

## Reglas

- **Traducir nunca da más permisos que el original.** Si una restricción no se
  puede replicar en esa IA, Run avisa o no arranca. `bypassPermissions` no se
  traduce.
- **Solo los Connectors declarados.** En Codex y Copilot el agente no hereda
  los MCP ni los plugins del usuario, y computer use nunca se hereda sin
  pedirlo.
- **Sin límites por defecto.** Tiempo y créditos son opcionales en Codex y
  Copilot: cortar una tarea por un número estimado puede costar más que dejarla
  terminar. Se muestra el consumo en vivo y Stop queda a mano.
- **Cada CLI en su archivo**, en `crates/domain/src/agent_defs/cli/`, detrás del
  trait `AgentCli`. Un cambio en una no alcanza a las otras.

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
  tocó, aun con `role_sentence`; `gpt-6-luna` lo respetó las dos. Muestra chica,
  pero alcanza para no usar `auto` en agentes.
- **Copilot no tiene límite de turnos.** Un agente de solo lectura con una tarea
  imposible hizo unas 30 llamadas a tools.
- **Primera vez en una carpeta.** En modo interactivo Copilot muestra "Confirm
  folder trust"; `--trust-folder` solo sirve para `-p`.
- **Fuera de un repo.** `codex exec` necesita `--skip-git-repo-check`.
- **Modelos.** Los alias de Claude rompen la corrida en las otras CLIs: siempre
  se mapean.

## Sin confirmar

- `--available-tools` de Copilot, necesario para sacar `skill` y `sql`, que
  siguen disponibles en un agente de solo lectura.
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
