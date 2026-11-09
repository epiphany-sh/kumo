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
  directa.
- `COPILOT_HOME`: una carpeta nueva queda sin sesión, pero falta probar que
  iniciar sesión ahí no pise el login del usuario. Hasta entonces Copilot sigue
  compartiendo el login entre workspaces (`crates/domain/src/agents/homes.rs`).
- Retomar una corrida cortada con `copilot --resume` y `codex exec resume`.
