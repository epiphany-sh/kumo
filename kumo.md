# Orquesta — brief para el agente

> Nombre de trabajo: **Orquesta** (provisorio, se puede cambiar).
> Este documento es el contexto completo para arrancar el repo. Leelo entero antes de escribir código.
> Fecha de redacción: 2026-10-27.

---

## 1. Qué estamos construyendo

Una **app de escritorio nativa para macOS y Windows** para orquestar agentes de IA que programan, inspirada en [Orca](https://www.onorca.dev) (stablyai/orca), con un diferencial claro:

- **Agentes en paralelo**: correr CLIs de agentes (Claude Code, Codex, OpenCode, Gemini, Copilot, cualquier CLI) cada uno en su propio **git worktree** aislado, en terminales dentro de la app.
- **Fuentes de tareas genéricas**: Orca integra GitHub y Linear. Nosotros queremos que cualquier herramienta con tareas sea fuente: **Jira, Notion, Obsidian, Todoist, Linear, GitHub Issues**, etc. De una tarea se abre un worktree con un agente, y el resultado vuelve a la tarea (estado, link al PR).
- **Repositorios**: worktrees, diffs, review de cambios de los agentes, commit.
- **Sensación instantánea**: es el requisito número uno. Ver la sección 4.

### No-objetivos (explícitos)

- **Nada de UI web**: ni Electron, ni Tauri, ni webviews. El dueño del proyecto lo descartó a propósito.
- No proxear modelos de IA: la app maneja los CLIs y suscripciones que el usuario ya tiene (bring your own agent).
- Linux no es prioridad. Que compile está bien, pero no se optimiza ni se testea al principio.
- Mobile: no por ahora, pero la arquitectura lo deja abierto (ver sección 3).

---

## 2. Decisiones tomadas (y por qué)

| Decisión | Elegido | Descartado | Motivo |
|---|---|---|---|
| Núcleo | **Rust**, como daemon independiente | Go, TypeScript | Manejo de PTYs, procesos y git con bajo overhead; un binario por SO |
| UI | **Flutter desktop** (macOS + Windows) | Electron/Tauri (es web); GPUI (pre-1.0, API inestable, poca documentación); SwiftUI + WinUI (dos UIs que mantener) | Compilada, sin webview, estable, hot reload, un solo código para ambos SO |
| UI ↔ núcleo | **gRPC sobre TCP loopback** | FFI (`flutter_rust_bridge`) | La misma API sirve para UI, CLI y una futura app mobile; aislamiento de fallos; UI reemplazable. Cuesta algo de latencia, pero es despreciable si se respeta el batching (sección 5) |
| Emulación de terminal | **En Rust** (el núcleo parsea y manda el estado de pantalla) | Paquete de terminal en Dart con bytes crudos | El parseo no compite con el render, y el scrollback sobrevive a cerrar la UI. Se hace en M2; en M0/M1 se usan bytes crudos para medir el transporte |
| Datos de tareas | **Caché local SQLite en el núcleo** + sync en segundo plano | Leer las APIs en vivo | La UI nunca espera a la red |

Si en algún momento los números de la sección 4 no se pueden cumplir con estas decisiones, **frená y reportalo con mediciones** en lugar de cambiar la arquitectura por tu cuenta.

---

## 3. Arquitectura

```
┌───────────────────────────┐        gRPC (HTTP/2, TCP 127.0.0.1)        ┌──────────────────────────────────┐
│  Flutter desktop (UI)     │  ───── unary: comandos ─────────────────▶ │  orquestad (daemon Rust)         │
│  - render de grilla term. │  ◀──── server-stream: eventos ─────────── │  - sesiones PTY (portable-pty)   │
│  - estado optimista       │  ◀───▶ bidi-stream: terminal ──────────── │  - emulador de terminal (M2)     │
│  - lanza/descubre daemon  │        auth: Bearer token                  │  - git / worktrees               │
└───────────────────────────┘                                            │  - supervisor de agentes (CLIs)  │
            ▲                                                            │  - conectores de tareas + SQLite │
            │ (futuro) misma API                                         │  - bus de eventos                │
   CLI `orquesta`, app mobile                                            └──────────────────────────────────┘
```

- El **daemon vive más que la UI**: si se cierra la ventana, los agentes y terminales siguen corriendo. Al reabrir, la UI se reconecta y hace replay.
- La UI **lanza el daemon si no está corriendo** y lo descubre por un archivo (sección 7).
- Toda comunicación del núcleo hacia la UI es **push** (streams). Nada de polling.

---

## 4. Presupuesto de rendimiento (requisito, no deseo)

Son **objetivos iniciales**. Se validan con mediciones reales en M0 y M1 y se ajustan con datos, nunca a ojo. Cada uno tiene que tener un benchmark o una traza que lo mida.

| Métrica | Objetivo | Cómo se mide |
|---|---|---|
| Eco de tecla, extremo a extremo (tecla → glifo en pantalla) | p50 ≤ 8 ms, **p99 ≤ 16 ms** (1 frame a 60 Hz) | Bench M1 en Flutter: timestamp al enviar vs. frame donde aparece |
| Tramo del daemon (bytes leídos del PTY → escritos al socket) | **p99 ≤ 2 ms** | `tracing` + timestamp en cada batch |
| RTT de gRPC unary en loopback (`Hello`) | **p99 ≤ 1 ms** | Bench M0 |
| Eco de tecla vía gRPC, sin UI (cliente Rust ↔ PTY con `cat` en raw) | p50 ≤ 1 ms, **p99 ≤ 3 ms** | Bench M0 |
| Throughput de terminal | **≥ 50 MB/s** sostenidos en el daemon; la UI mantiene **60 fps** con salida pesada (ej. `cargo build`, `seq 1 5000000`) | Bench M0 (daemon) y M1 (UI) |
| Acción en la UI (mover tarea, lanzar agente, cambiar de tab) | Feedback visual **≤ 16 ms** (optimista); confirmación del núcleo **≤ 100 ms** | Trazas en la UI |
| Abrir la app con el daemon ya corriendo → UI interactiva | **≤ 500 ms** | Medición de arranque |
| Abrir la app con el daemon frío | **≤ 1.5 s** | Medición de arranque |
| Listar/filtrar tareas desde la caché local | **≤ 50 ms** con 10.000 tareas | Bench sobre SQLite |
| Memoria del daemon en reposo | **≤ 50 MB** | Medición |

**Regla:** ningún PR que toque el camino caliente (PTY, streaming, render de terminal) entra si empeora estos números sin justificación escrita.

---

## 5. Reglas de diseño para que se sienta instantáneo

1. **Local-first.** La UI lee siempre de estado local (memoria del núcleo o SQLite). Jira, Notion, etc. se sincronizan en segundo plano y emiten eventos cuando cambian.
2. **UI optimista.** Ante una acción, la UI cambia en el mismo frame; el núcleo confirma o revierte con un evento.
3. **Push, nunca polling.** Streams gRPC para eventos, file watchers para Obsidian (es una carpeta de markdown), webhooks o sync incremental para las APIs.
4. **Coalescing sin latencia agregada.** El lector del PTY manda chunks a un canal acotado. La tarea "pump" toma un chunk y **drena lo que ya esté en el canal** (`try_recv`) hasta un máximo (ej. 256 KiB) y lo manda como un batch. **No usar timers fijos** de 16 ms: con tráfico bajo (tipeo) cada byte sale al instante; con tráfico alto los batches crecen solos mientras el envío anterior está en vuelo.
5. **Backpressure de punta a punta.** Canales acotados. Si el consumidor es lento, se frena la lectura del PTY y con eso el proceso hijo, como una terminal real. Para estados "último gana" (progreso, status de agente) se descartan los intermedios.
6. **Render por frame en la UI.** Flutter acumula lo recibido y pinta una vez por frame (`CustomPainter` sobre la grilla), nunca un rebuild por mensaje.
7. **Daemon siempre caliente** (ver sección 3).
8. **Medir desde el día uno.** `tracing` en Rust, timestamps en los mensajes del camino caliente y benchmarks reproducibles en el repo.
9. **TCP_NODELAY** en servidor y cliente. Sin eso, Nagle mete decenas de ms en el eco de tecla.

---

## 6. Stack y versiones

Versiones verificadas en crates.io el **2026-10-27** (rustc 1.97). Antes de fijarlas, volvé a verificar que no haya versiones nuevas con cambios relevantes.

| Crate | Versión | Uso |
|---|---|---|
| `tonic` | 0.14.8 | Servidor y cliente gRPC |
| `tonic-prost` / `tonic-prost-build` | 0.14.8 | Codec y codegen (en 0.14 el codegen de prost está separado de `tonic-build`) |
| `prost` | 0.14.4 | Protobuf |
| `protoc-bin-vendored` | 3.3.0 | `protoc` embebido, para no depender del sistema (setear `PROTOC` en `build.rs`) |
| `tokio` | 1.54.1 | Runtime async |
| `tokio-stream` | 0.1.19 | Adaptadores de streams |
| `portable-pty` | 0.9.0 | PTY multiplataforma (ConPTY en Windows) |
| `tracing`, `tracing-subscriber` | última | Trazas y medición |
| `bytes` | última | Buffers sin copias (configurar prost para usar `Bytes` en campos `bytes`) |

**Sin verificar todavía (hacelo antes de usarlos):**
- Emulador de terminal en Rust para M2: candidato `alacritty_terminal` (lo usa Zed). Confirmar API, licencia y mantenimiento.
- Flutter: paquete `grpc` de Dart y `protoc_plugin` para generar el cliente. Confirmar versiones y soporte de streaming bidireccional en desktop.
- Git: `gix` vs. `git2` vs. invocar el binario `git`. Para worktrees, invocar `git` es lo más simple y confiable al principio.
- SQLite: `rusqlite` o `sqlx`.
- MCP: SDK oficial de Rust, por si el núcleo actúa como cliente MCP para conectores.

---

## 7. Seguridad y ciclo de vida del daemon

El daemon **ejecuta comandos**, así que tiene que estar cerrado:

- Escucha **solo en loopback** (`127.0.0.1`, puerto efímero). Si se le pide bindear a otra interfaz, **error al arrancar**.
- **Token aleatorio** (32 bytes, hex) generado en cada arranque. Toda llamada lleva `authorization: Bearer <token>`; se valida en un interceptor con comparación de tiempo constante.
- **Archivo de descubrimiento** `daemon.json` en el directorio de datos del usuario (`dirs::data_local_dir()/orquesta/`), con `{ api_version, pid, addr, token }`. En Unix, permisos `0600`. Se escribe atómicamente (temporal + rename) y se borra al cerrar.
- **Una sola instancia**: al arrancar, si el archivo existe y el `Hello` responde, salir con "ya está corriendo".
- **Handshake de versión**: el `Hello` devuelve `api_version`; la UI se niega a operar si no coincide y ofrece reiniciar el daemon.
- La UI lanza el daemon como proceso hijo desacoplado (que sobreviva a la UI), espera al archivo, se conecta y reintenta con backoff si se cae.

---

## 8. Contrato gRPC inicial (borrador v1)

Ubicación: `proto/orquesta/v1/orquesta.proto`. Es un punto de partida; ajustalo si hace falta, pero mantené la compatibilidad hacia atrás una vez que la UI lo consuma.

```proto
syntax = "proto3";
package orquesta.v1;

service Core {
  rpc Hello(HelloRequest) returns (HelloResponse);
}

service Terminals {
  rpc Open(OpenRequest) returns (OpenResponse);
  // Primer mensaje del cliente: AttachTo. Después: data / resize.
  rpc Attach(stream TerminalInput) returns (stream TerminalOutput);
  rpc Close(CloseRequest) returns (CloseResponse);   // mata el proceso
  rpc List(ListRequest) returns (ListResponse);
}

message HelloRequest  { uint32 client_api_version = 1; string client_name = 2; }
message HelloResponse { uint32 server_api_version = 1; string server_version = 2; uint64 server_time_unix_nanos = 3; }

message OpenRequest {
  string program = 1; repeated string args = 2; string cwd = 3;
  map<string, string> env = 4; uint32 cols = 5; uint32 rows = 6;
}
message OpenResponse { string terminal_id = 1; }

message TerminalInput {
  oneof kind { AttachTo attach = 1; bytes data = 2; Resize resize = 3; }
}
message AttachTo { string terminal_id = 1; bool replay_scrollback = 2; }
message Resize   { uint32 cols = 1; uint32 rows = 2; }

message TerminalOutput {
  oneof kind { OutputBatch output = 1; Exited exited = 2; }   // M2: agregar ScreenUpdate
}
message OutputBatch {
  uint64 seq = 1;                    // monotónico por sesión; replay y vivo no se solapan
  bytes data = 2;
  uint64 first_read_unix_nanos = 3;  // cuándo se leyó del PTY el primer chunk (para medir latencia)
  uint32 chunks = 4;                 // cuántos chunks se coalescieron
}
message Exited { int32 exit_code = 1; }

message CloseRequest  { string terminal_id = 1; }
message CloseResponse {}
message ListRequest   {}
message ListResponse  { repeated TerminalInfo terminals = 1; }
message TerminalInfo  { string terminal_id = 1; string program = 2; bool exited = 3; int32 exit_code = 4; }
```

### Diseño de una sesión de terminal (daemon)

- **Hilo lector** (bloqueante): `read()` del master del PTY y envío de `(Bytes, timestamp)` a un `mpsc` acotado. En Linux/macOS `EIO` al terminar el hijo equivale a EOF.
- **Hilo escritor** (bloqueante): recibe input de un `mpsc` y hace `write_all` + `flush` al PTY.
- **Hilo de espera**: `child.wait()` y envío del exit code por un `oneshot`. Guardar `clone_killer()` antes para `Close`.
- **Soltar el `slave`** después de hacer spawn; si no, el EOF nunca llega.
- **Tarea pump** (tokio): coalescing según la regla 4, número de secuencia, push a un **buffer de replay acotado** (ej. 2 MiB) y envío a cada suscriptor con `.await` (backpressure). En M0/M1 basta con un suscriptor activo, pero debe soportar varios.
- **Suscribir es atómico**: bajo el mismo lock se toma el snapshot del replay y se registra el suscriptor, y el pump empuja al replay y clona la lista de suscriptores bajo ese lock. Así replay y vivo no se solapan ni pierden batches.
- Una sesión terminada queda en el registro con su exit code hasta que se llama a `Close`.
- Setear `TERM=xterm-256color` si no viene en `env`.
- **Windows (ConPTY)**: `portable-pty` lo abstrae, pero ConPTY reescribe la salida y tiene particularidades de resize. Testear en Windows real desde M0, no al final.

---

## 9. Estructura del repo

```
orquesta/
├── AGENTS.md                 ← este archivo
├── README.md                 ← cómo correr todo, en Mac y Windows
├── Cargo.toml                ← workspace (resolver 3, edition 2024)
├── proto/orquesta/v1/orquesta.proto
├── crates/
│   ├── proto/                ← codegen tonic/prost (build.rs + protoc vendored)
│   ├── core/                 ← lib: terminal, server, auth, discovery
│   │   ├── src/main.rs       ← binario `orquestad`
│   │   └── tests/            ← tests de integración (servidor en proceso)
│   └── bench/                ← binario `orquesta-bench`: echo, throughput, hello
├── app/                      ← proyecto Flutter desktop (desde M1)
└── docs/
    ├── adr/                  ← una decisión por archivo (las de la sección 2 son el ADR-0001)
    └── perf/                 ← resultados de benchmarks con fecha, máquina y SO
```

---

## 10. Hitos

Cada hito tiene criterios de salida medibles. No se pasa al siguiente sin cumplirlos o sin una decisión documentada.

### M0 — Núcleo y transporte (solo Rust)
- Workspace, `.proto`, daemon `orquestad` con `Core` y `Terminals`, auth por token, archivo de descubrimiento.
- `orquesta-bench` con tres modos:
  - `hello`: RTT unary (N=10.000).
  - `echo`: abre `sh -c "stty raw -echo; printf READY; exec cat"`, espera `READY`, manda 1 byte por vez con ~2 ms de pausa (N=1.000, con warmup) y mide hasta recibir el eco. Reporta p50, p95, p99 y máximo, más la parte del daemon usando `first_read_unix_nanos`.
  - `throughput`: `seq 1 5000000` y `head -c 100M /dev/zero | tr '\0' x`. Reporta MB/s, cantidad de batches y tamaño promedio.
- Tests de integración: salida y exit code; token inválido rechazado; **detach y reattach con replay** (la sesión sobrevive y no se pierden ni duplican batches).
- **Salida:** números de la sección 4 para M0 cumplidos en macOS y Windows, guardados en `docs/perf/`. En Windows, el bench `echo` necesita un programa equivalente (por ejemplo un pequeño binario de eco en Rust incluido en el workspace).

### M1 — Spike de UI en Flutter (go / no-go)
- App Flutter desktop que lanza o descubre el daemon, hace `Hello`, abre una terminal y la muestra.
- Render con `CustomPainter`, todavía sobre bytes crudos con un parser mínimo, para medir solo transporte y render.
- **Salida:** eco extremo a extremo p99 ≤ 16 ms y 60 fps con `seq 1 5000000`, en Mac y Windows. **Si no se cumple, se frena y se reporta con datos.** La alternativa evaluada es GPUI.

### M2 — Emulador en Rust
- Integrar el emulador (candidato `alacritty_terminal`) en el daemon. Agregar `ScreenUpdate` al proto con **diffs de líneas sucias**, no la pantalla entera.
- Scrollback persistente en el daemon; reattach muestra la pantalla exacta.
- **Salida:** mismos números que M1 con `vim`, `htop` y TUIs de agentes (Claude Code, Codex).

### M3 — Worktrees y agentes
- Crear y borrar worktrees, lanzar un CLI de agente en cada uno, estado del agente (corriendo, esperando input, terminado) como stream de eventos.
- Vista de diffs por worktree, commit, notificaciones.

### M4 — Fuentes de tareas
- Modelo de tarea unificado y caché SQLite en el núcleo.
- Conectores en este orden sugerido: Obsidian (archivos locales + watcher), GitHub Issues, Linear, Jira, Todoist, Notion. Evaluar si conviene que el núcleo use MCP como cliente para algunos.
- De una tarea se abre un worktree con un agente; al terminar, se actualiza la tarea (estado y link al PR).
- **Salida:** listar y filtrar 10.000 tareas en ≤ 50 ms; ninguna interacción de UI espera a la red.

### M5 — Distribución
- Empaquetado con dos binarios (UI y daemon): `.app` firmado y notarizado en macOS e instalador firmado en Windows.
- Auto-update y migración de versión del daemon.

---

## 11. Cómo tiene que trabajar el agente

- **Medí, no supongas.** Toda afirmación de rendimiento va con un número y cómo se obtuvo.
- **Verificá versiones y APIs** antes de usarlas (las de la sección 6 pueden haber cambiado). No inventes APIs de crates: leé la doc o el código.
- **Nada de webviews** ni dependencias que las traigan.
- **Tests y bench en CI** desde M0 (macOS y Windows como mínimo).
- **Commits chicos** y descriptivos; cada hito cierra con un resumen en `docs/perf/` y los ADRs nuevos en `docs/adr/`.
- **Preguntá antes de** cambiar una decisión de la sección 2, agregar una dependencia pesada o tomar cualquier cosa irreversible (licencia, nombre público, publicar algo).
- Código y comentarios en inglés; docs en español rioplatense (o como prefiera el dueño).

---

## 12. Preguntas abiertas (para el dueño del proyecto)

- Nombre definitivo y licencia (open source o no).
- ¿Producto para terceros o herramienta personal? Cambia la prioridad de M5 y de la telemetría.
- ¿Extender Orca (es open source) en algún punto, o todo propio? Hoy la decisión es todo propio.
- ¿Conectores directos por API o vía MCP? Probablemente una mezcla; definir en M4.
- ¿App mobile complementaria en el futuro? La API gRPC ya lo permite.
