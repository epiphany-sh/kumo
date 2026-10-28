# M4 — Tareas, macOS (2026-10-28)

`make bench` → escenario `kumo-bench tasks` (release, macOS aarch64, 12 CPUs).
Vault de Obsidian generado: 500 notas × 20 checkboxes = 10.000 tareas. Sin red.

| Medición | Resultado | Presupuesto |
| --- | --- | --- |
| Abrir el tablero por gRPC (10k tareas, desde memoria del daemon) | p50 15,1 ms · p99 16,7 ms | ✅ ≤ 50 ms |
| Cargar 10k tareas de la caché SQLite (arranque del daemon) | p50 7,8 ms · p99 8,5 ms | ✅ ≤ 50 ms |
| Filtrar 10k tareas (texto + estado) | p50 0,49 ms · p99 1,34 ms | ✅ ≤ 50 ms |
| Primera lectura del vault (escaneo + parseo + caché + push) | 75 ms | — |
| Edición externa de una nota hasta el push (incluye 150 ms de asentamiento) | 247 ms | — |

En vivo, contra los vaults reales del usuario (solo lectura): uno en iCloud con
30 tareas tardó 1,7 s en la primera lectura (archivos de iCloud), los demás
menos de 70 ms. Las lecturas siguientes solo reparsean las notas que cambiaron.
