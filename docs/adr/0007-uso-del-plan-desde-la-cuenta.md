# ADR-0007 — Uso del plan: preguntarle a la cuenta con el login de cada CLI

- Estado: aceptada
- Fecha: 2026-11-10

## Contexto

"AI usage" mostraba lo que le queda a cada plan solo cuando alguna sesión lo
había dicho: el status line de Claude Code o los archivos de sesión de Codex.
Sin un agente corriendo desde hacía un rato, o recién instalado, no había nada
para mostrar, y Copilot no se leía nunca.

Las tres cuentas dan el mismo número que muestran sus CLIs (`/usage`,
`/status`) a quien se lo pide con el login que la CLI ya guardó:

| CLI | Login | Pregunta |
| --- | --- | --- |
| Claude Code | llavero de macOS `Claude Code-credentials` (con `CLAUDE_CONFIG_DIR`: `…-<8 hex del sha256 de la carpeta>`); en otros sistemas `<carpeta>/.credentials.json` | `GET api.anthropic.com/api/oauth/usage` |
| Codex | `<CODEX_HOME>/auth.json` | `GET chatgpt.com/backend-api/wham/usage` |
| Copilot CLI | `COPILOT_GITHUB_TOKEN`/`GH_TOKEN`/`GITHUB_TOKEN`, llavero `copilot-cli`, `gh auth token` | `GET api.github.com/copilot_internal/user` |

## Decisión

- Un puerto nuevo, `AccountUsage`, que le pregunta a la cuenta. Las sesiones
  (`UsageSource`) siguen: dan el contexto y actualizan el plan entre preguntas.
  Una sesión reemplaza solo las ventanas que ve (5 h, semanal) y deja las que
  solo sabe la cuenta (el semanal de un modelo).
- La cuenta se pregunta cuando la UI pide el uso y ya toca: cada 2 minutos si
  contestó, cada minuto si rechazó el login (el usuario puede estar entrando de
  nuevo), cada 5 si no se pudo preguntar. Nunca dos preguntas a la vez.
- **Kumo solo lee los logins; nunca los escribe.** Si el de Claude Code venció,
  corre `claude auth status`, que lo renueva y lo guarda Claude Code mismo
  (probado con 2.1.322). El de Codex lo renueva Codex cuando corre; si la
  cuenta lo rechaza, se avisa.
- Sin login, o rechazado, el plan dice por qué y ofrece entrar de nuevo desde
  Ajustes › AI agents (`needs_sign_in`). Sin conexión, sigue mostrando lo último
  leído hasta que se reinicie su ventana.
- Cada perfil pregunta con sus propios logins (las carpetas de
  [ADR-0006](0006-workspaces-como-perfiles.md)); Copilot comparte el del
  usuario.
- Leer el llavero va por `/usr/bin/security`, la herramienta con la que Claude
  Code guarda el suyo: no pregunta nada. El de Copilot lo guardó otro programa,
  así que macOS pregunta una vez; si el usuario no lo permite, no se vuelve a
  pedir mientras Kumo corra y se prueba con `gh`.

## Consecuencias

- Los endpoints no están documentados: pueden cambiar. Cada respuesta se lee
  campo por campo, y lo que no se entiende queda afuera, nunca se estima.
- Gemini CLI y Grok no se leen: el login de Gemini vence cada hora y renovarlo
  exigiría escribirlo, y para Grok no se conoce una forma de pedir el uso.
