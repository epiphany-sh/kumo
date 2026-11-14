# ADR-0008 — Modelo y effort del agente: lo que cada CLI dice de sí

- Estado: aceptada
- Fecha: 2026-11-14

## Contexto

La barra de estado de la terminal muestra la rama. Hace falta mostrar también
con qué modelo y qué effort corre el agente del pane enfocado, que cambie si el
usuario lo cambia desde la terminal (`/model`, `/effort`) y que siga a la
pestaña. Tiene que servir para Claude Code, Codex y Copilot, tanto en los
agentes que lanza Kumo como en los que alguien tipea a mano en una shell
(`claude` en zsh).

Ninguna CLI expone esto por una API. Cada una lo escribe en sus propios
archivos (probado con Claude Code 2.1.325, Codex 0.157 y Copilot 1.0.108):

| CLI | Lanzada por Kumo | Tipeada a mano |
| --- | --- | --- |
| Claude Code | el JSON de su status line (`model.display_name`, `effort.level`), que Kumo ya guarda con `--settings` | `<config>/sessions/<pid>.json` da la sesión y el `cwd`; el transcript `<config>/projects/<cwd>/<sesión>.jsonl` trae `message.model` y `effort` en cada respuesta |
| Codex | el rollout de la sesión: `turn_context` (`model`, `effort`) en cada turno | el mismo rollout, buscado por `cwd` y hora de inicio |
| Copilot | `session-state/<id>/events.jsonl`: `session.model_change` (`newModel`, `reasoningEffort`) y `session.auto_mode_resolved` | la misma carpeta, la que tiene `inuse.<pid>.lock` |

## Decisión

- Lo leen las mismas `UsageSource` que ya leían el contexto y el plan:
  `UsageReading` suma `effort`, y una fuente nueva, `CopilotEvents`, lee
  Copilot. Leer modelo y effort depende del mismo switch "read usage" de cada
  proveedor.
- `UsageTarget` suma el `pid` del proceso cuando se conoce (CLI tipeada a
  mano). Con pid, Claude Code se lee del transcript en vez del status line, y
  Copilot busca primero la carpeta que ese proceso tiene abierta.
- El daemon publica el resultado en `Agents.Watch` (`AgentSession.model`/
  `effort` y `TerminalAgent.model`/`effort`), no solo en `Agents.Usage`: la
  UI se entera de un cambio en unos 2 segundos sin consultar.
- La UI lo muestra en la barra de estado, junto a la rama, para el pane
  enfocado de la pestaña visible. Un agente que ya terminó no muestra nada.

## Consecuencias

- Solo se muestra lo que la CLI escribió. Copilot e instancias tipeadas de
  Claude Code escriben recién con el primer mensaje: antes no se muestra nada,
  y nunca se deduce de la configuración del usuario.
- Un cambio de modelo se ve cuando la CLI lo escribe: en Claude Code y Codex,
  con la próxima respuesta o el próximo turno.
- Los archivos de sesión no están documentados: pueden cambiar. Cada línea se
  lee campo por campo, y lo que no se entiende queda afuera.
- Codex no deja nada que asocie un proceso con su rollout. Una sesión tipeada a
  mano se asocia, como las que lanza Kumo, al rollout más nuevo de su `cwd` que
  empezó desde poco antes de que Kumo la viera; con dos Codex arrancados a la
  vez en la misma carpeta, puede tomar el del otro. Un `codex resume` sigue un
  rollout viejo y no se encuentra: no muestra nada.
