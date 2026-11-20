# Git y watcher, macOS (2026-11-14)

`cargo build --release` → `kumo-bench git` (macOS aarch64, 12 CPUs, git 2.54).
Repo generado: 200 archivos trackeados, `.gitignore` con `target/` y
`node_modules/`, un worktree enlazado al lado, en un namespace y con el panel
de cambios abierto en el checkout principal. Los procesos `git` se cuentan con
`GIT_TRACE2_EVENT` (un archivo por proceso que lanza el daemon).

Primer cambio medido: H1 del [reporte de performance](../performance-report-2026-11-14.md),
el watcher deja de reaccionar a lo que pasa dentro de carpetas ignoradas por git.

| Medición | Antes | Después |
| --- | --- | --- |
| Inactivo, 3 s | 0 procesos | 0 procesos |
| Build de 10 s: ~4.300 escrituras en `target/` (ignorado) | 406–417 procesos (≈41/s) | 11 procesos (1,1/s) |
| Actualizaciones del panel durante el build | 0 | 0 |
| Por edición de un archivo trackeado | 15 procesos | 15 procesos |
| Edición → panel de cambios | 264–275 ms | 258–271 ms |

Durante el build se pasa de una relectura continua (workspace cada ~300 ms y
panel cada ~150 ms) a **una sola**: la que dispara crear la carpeta `target/`,
que a propósito sigue contando (ver `watch/ignored.rs`). Son **−97 %** de los
procesos `git` en este escenario; con un build más largo el ahorro relativo
crece, porque lo que queda no depende de la duración.

Las ediciones reales no cambian: siguen siendo 15 procesos por edición (status
del panel + dos relecturas del repo). Ese es el terreno de H2 y H4.
