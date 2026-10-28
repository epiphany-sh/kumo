# Kumo

App de escritorio para orquestar agentes de IA que programan. Este repo tiene
el **engine** (daemon `kumod`, en Rust) y la UI (`kumo-ui/`, Flutter).
El brief completo está en [`kumo.md`](kumo.md).

## Requisitos

- Rust **1.99** (fijado en `rust-toolchain.toml`; `rustup` lo instala solo).
- Flutter **3.47+** con Xcode (macOS) o Visual Studio (Windows) para la UI.
- Nada más: `protoc` viene embebido (`protoc-bin-vendored`).

## Correr la app completa

```bash
make run
```

Compila `kumod` y la app Flutter en release, mete `kumod` adentro del bundle
(`kumo_ui.app/Contents/MacOS/kumod`), reinicia el daemon y abre la app. La app
descubre el daemon por `daemon.json` o lo lanza desacoplado si no está corriendo.

| Comando | Qué hace |
|---|---|
| `make run` | Todo en release y abre la app |
| `make dev` | `kumod` release + `flutter run` en debug (hot reload) |
| `make status` / `make stop` | Estado del daemon / pararlo (mata sus terminales) |
| `make test` / `make check` | Tests y lints de Rust y Flutter |
| `make bench` | Benchmarks del daemon |
| `make proto` | Regenera el cliente Dart desde `proto/` |

Qué es real hoy y qué sigue siendo mock:

| Área | Estado |
|---|---|
| Terminales (shells) | Real: PTYs en `kumod`, render en grilla de celdas |
| Namespaces, repos y worktrees | Real: `Workspace` en `kumod`, persistido en `kumo.db` (SQLite) |
| Files, cambios de git, diffs, commit, push, historial | Real: `Git` en `kumod`; el estado se actualiza solo (file watcher) |
| Gráfico de ramas del historial, panel Diff de la vista Git | Mock |
| Agentes, tareas, PRs, pipelines, docs, integraciones | Mock (M3 / M4) |

El daemon vive más que la UI: si cerrás la app, las terminales siguen corriendo
y al reabrirla la UI se vuelve a enganchar a ellas con replay.

## Solo el daemon

```bash
cargo run --release -p kumod
```

Escucha en `127.0.0.1` (puerto efímero). En el directorio de datos guarda el archivo de
descubrimiento y `kumo.db` (namespaces y repos). Los worktrees nuevos van por defecto a
`~/wt/<repo>/<branch>`. El archivo de descubrimiento está en:

| SO      | Ruta                                              |
|---------|---------------------------------------------------|
| macOS   | `~/Library/Application Support/kumo/daemon.json`  |
| Windows | `%LOCALAPPDATA%\kumo\daemon.json`                 |

```json
{ "api_version": 1, "pid": 1234, "addr": "127.0.0.1:52769", "token": "<64 hex>" }
```

Opciones: `--listen 127.0.0.1:0`, `--data-dir <dir>`, `--worker-threads 2`.
Logs con `RUST_LOG=kumod=debug,kumo_application=trace`.

## Tests y benchmarks

```bash
cargo test --workspace
```

```bash
cargo build --release --workspace && ./target/release/kumo-bench all
```

`kumo-bench` levanta su propio `kumod` en un directorio temporal. Modos:
`hello`, `echo`, `throughput`, `all`. Resultados en [`docs/perf/`](docs/perf/).

## Estructura

Arquitectura en capas (clean / hexagonal): cada capa es un crate, así el
compilador garantiza que las dependencias apunten solo hacia adentro.
Detalle y motivos en [ADR-0002](docs/adr/0002-capas-y-estructura.md).

```
kumo/
├── Cargo.toml                  workspace (resolver 3, edition 2024)
├── proto/kumo/v1/kumo.proto    contrato gRPC (fuente de verdad para Rust y Dart)
├── crates/
│   ├── domain/                 kumo-domain: entidades, value objects, reglas y puertos (traits). Sin I/O.
│   │   └── src/
│   │       ├── terminal/       TerminalId, TerminalSize, LaunchSpec, OutputBatch, BatchBuilder,
│   │       │                   ReplayBuffer, ExitStatus, TerminalStatus, puertos PtySystem/PtyMaster/…
│   │       ├── daemon/         ApiVersion, AuthToken, ListenAddress (solo loopback),
│   │       │                   DaemonEndpoint, puerto DiscoveryStore
│   │       └── time.rs         Timestamp
│   ├── application/            kumo-application: casos de uso
│   │   └── src/
│   │       ├── terminal/       TerminalService (open/attach/close/list), registry,
│   │       │   └── session/    TerminalSession: hilos de I/O, pump (coalescing), hub (replay + suscriptores)
│   │       └── daemon/         HelloService (handshake de versión)
│   ├── infrastructure/         kumo-infrastructure: adaptadores del SO
│   │   └── src/{pty, discovery, security}/   portable-pty, daemon.json (0600, atómico), token aleatorio
│   ├── proto/                  kumo-proto: código generado (tonic/prost), nada más
│   ├── grpc/                   kumo-grpc: servicios tonic, auth Bearer, mapeo proto↔dominio, server y client
│   ├── daemon/                 kumod: composition root + binario + tests de integración (tests/)
│   └── bench/                  kumo-bench (hello/echo/throughput) y kumo-echo (helper para Windows)
├── docs/adr/                   decisiones, una por archivo
├── docs/perf/                  resultados de benchmarks con fecha, máquina y SO
└── kumo-ui/                    Flutter desktop (M1)
```

Dependencias entre crates: `domain ← application ← {infrastructure, grpc} ← kumod`.

## La UI (`kumo-ui/`)

- `lib/engine/`: cliente del daemon.
  - `generated/`: código generado desde el `.proto` (`make proto`).
  - `daemon_endpoint.dart` lee `daemon.json`; `daemon_launcher.dart` busca y lanza `kumod`.
  - `kumo_engine.dart`: handshake `Hello` con token y versión; `grpc_terminal_surface.dart`
    implementa `TerminalSurface` sobre `Terminals.Open` + `Attach` (bidi).
- `lib/terminal/ansi_screen.dart`: parser ANSI mínimo (M1). En M2 lo reemplaza el emulador en el daemon.
- `lib/terminal/grid_renderer.dart`: render en grilla de celdas. Fondos a alto de celda, texto anclado a
  `columna × ancho`, íconos centrados por celda, ancho doble (`cell_width.dart`), y powerline / box drawing /
  bloques dibujados como formas (`drawn_glyphs.dart`). Cada fila se graba en un `Picture` cacheado hasta que
  cambia. `make bench-ui` mide el costo en modo profile.
- `lib/terminal/terminal_keys.dart`: teclas → bytes (convenciones xterm); ⌘ queda para los atajos de la app.
- La salida se parsea al llegar y se pinta como mucho una vez por frame (kumo.md §5.6).
- Fuente de la terminal: GeistMono con fallback a **Symbols Nerd Font Mono** (MIT, v3.5.1,
  `assets/fonts/`), para los íconos de prompts como oh-my-posh o starship.
- El panel del agente sigue siendo mock hasta M3; las shells (+, ⌘T, ⌘D) son reales.
- macOS: la app corre **sin App Sandbox** (ejecuta shells y lanza `kumod`).
