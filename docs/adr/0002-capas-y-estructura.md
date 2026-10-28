# ADR-0002 — Capas como crates (clean architecture)

- Estado: aceptada
- Fecha: 2026-10-27

## Contexto

`kumo.md` §9 proponía un único crate `core` con todo adentro. El dueño pidió
explícitamente clean code, un namespace por entidad y una carpeta `domain`.

## Decisión

Cada capa es un crate del workspace, y dentro de cada crate cada concepto es un
módulo (carpeta con `mod.rs`, un archivo por entidad o value object):

```
kumo-domain  ←  kumo-application  ←  kumo-infrastructure
                                  ←  kumo-grpc (+ kumo-proto)
                                         ↖
                                          kumod (composition root)
```

- **domain**: tipos y reglas puras. Sin tokio, sin tonic, sin I/O. Define los
  puertos (`PtySystem`, `DiscoveryStore`) que implementan las capas externas.
- **application**: casos de uso (`TerminalService`, `HelloService`). Usa tokio
  para concurrencia pero no conoce gRPC ni el SO.
- **infrastructure**: adaptadores del SO (`portable-pty`, archivo de
  descubrimiento, CSPRNG).
- **grpc**: adaptador de transporte; el mapeo proto ↔ dominio vive acá, no en el dominio.
- **kumod**: arma todo e inyecta dependencias. Es el único que conoce todas las capas.

Convenciones: `mod.rs` por carpeta para que cada carpeta sea un paquete
autocontenido; re-exports explícitos (`pub use`) en cada `mod.rs`; tipos
privados al módulo salvo que otra capa los necesite.

## Consecuencias

- El compilador impide dependencias hacia afuera (el dominio no puede importar tonic).
- Los casos de uso se testean sin red y los puertos se pueden reemplazar (ej. un
  emulador en M2, otro transporte, fakes en tests).
- Más `Cargo.toml` que mantener; las versiones se centralizan en `[workspace.dependencies]`.
