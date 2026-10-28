# ADR-0001 — Decisiones iniciales de arquitectura

- Estado: aceptada
- Fecha: 2026-10-27

## Contexto

Ver `kumo.md` §1–§5. El requisito número uno es que la app se sienta instantánea,
con agentes en paralelo y sin UI web.

## Decisión

| Tema | Elegido | Descartado |
|---|---|---|
| Núcleo | Rust, daemon independiente (`kumod`) | Go, TypeScript |
| UI | Flutter desktop (macOS + Windows) | Electron/Tauri, GPUI, SwiftUI + WinUI |
| UI ↔ núcleo | gRPC sobre TCP loopback, auth Bearer | FFI (`flutter_rust_bridge`) |
| Emulación de terminal | En Rust (M2); bytes crudos en M0/M1 | Paquete de terminal en Dart |
| Datos de tareas | Caché SQLite en el núcleo + sync en segundo plano | Leer APIs en vivo |

## Consecuencias

- La misma API sirve para UI, CLI y una futura app mobile.
- El daemon vive más que la UI: terminales y agentes sobreviven a cerrar la ventana.
- Cuesta algo de latencia de transporte; medida en `docs/perf/` (RTT p99 ≈ 0,07 ms).
