# ADR-0005 — Fuentes de tareas (M4): conectores directos, caché SQLite y tokens en el llavero

- Estado: aceptada
- Fecha: 2026-10-28

## Contexto

M4 pide un modelo de tarea unificado, caché local y conectores, con una regla
dura: listar y filtrar 10.000 tareas en ≤ 50 ms y que ninguna interacción de la
UI espere a la red. La pregunta abierta de `kumo.md` §12 era si conectar por API
o vía MCP. El dueño eligió la primera tanda: Obsidian, Bear, GitHub Issues, Jira
y Todoist.

## Decisión

- **Conectores directos**, uno por herramienta, detrás del puerto
  `TaskConnector` (dominio). MCP no: agrega un proceso por fuente, otro formato
  de auth y no da nada que estas cinco APIs no den. Se puede sumar como un
  conector más si aparece una fuente que solo hable MCP.
- **Caché local primero.** El daemon guarda fuentes, tareas y vínculos con
  worktrees en `kumo.db` (paso 3 de las migraciones) y sirve el tablero desde
  memoria. Cada fuente activa tiene un worker en segundo plano:
  - locales (Obsidian, Bear): se releen cuando cambian sus archivos (watcher,
    150 ms de asentamiento); Obsidian solo vuelve a parsear las notas cuyo
    mtime o tamaño cambió;
  - APIs (GitHub, Jira, Todoist): cada 3 minutos y cuando el usuario pide
    "Sync now". Una app de escritorio no puede recibir webhooks.
- **`Tasks.Watch`** empuja el tablero ("último gana"); cada mensaje lleva todas
  las fuentes pero solo las listas de tareas que cambiaron (versión por fuente).
- **Escritura de estado optimista**: el tablero cambia al instante y vuelve
  atrás si la herramienta lo rechaza. Cada tipo declara qué estados puede
  escribir (`SourceKind::writable`): Obsidian `[ ]`/`[/]`/`[x]`; GitHub y
  Todoist cerrar/reabrir; Jira por la transición de su workflow que lleva a la
  categoría pedida; Bear es de solo lectura (no hay forma segura de cambiar una
  línea de una nota desde afuera).
- **Credenciales**: GitHub usa el `gh` del usuario (Kumo nunca ve el token).
  Jira y Todoist necesitan un token, que va al llavero del sistema (Keychain en
  macOS, Credential Manager en Windows) vía `keyring-core` con los stores
  nativos; nunca a `kumo.db`. Los tests del daemon usan un store en memoria.
- **HTTP**: `ureq` (bloqueante, encaja con los puertos que bloquean) sobre el TLS
  y el almacén de certificados del sistema (`native-tls`), para que funcionen
  proxies corporativos y CAs propias.

## Consecuencias

- Dependencias nuevas: `ureq`, `base64`, `keyring-core`,
  `apple-native-keyring-store`, `windows-native-keyring-store`.
- macOS pregunta una vez si `kumod` puede leer el token del llavero; como el
  binario se firma ad hoc, vuelve a preguntar después de cada build nuevo.
- Bear: macOS puede pedir permiso para leer datos de otra app la primera vez.
- Los vaults en iCloud con "optimizar almacenamiento" pueden tener notas no
  descargadas; leerlas puede disparar la descarga.
- Pendiente: que al terminar el trabajo la tarea reciba el link al PR (necesita
  la integración de PRs) y conectores de Linear, Notion y Trello.
