# ADR-0004 — M3 (worktrees y agentes) antes que M2 (emulador en Rust)

- Estado: aceptada
- Fecha: 2026-10-27

## Contexto

`kumo.md` §10 ordena M2 (emulador en el daemon) antes de M3. Con el parser ANSI
mínimo y el render en grilla de celdas (`kumo-ui/lib/terminal/`), las shells y
prompts reales (oh-my-posh, starship) ya se ven bien. La UI sigue mostrando datos
mock en repos, worktrees, git, agentes y tareas.

## Decisión

Reemplazar los mocks por funcionalidad real empezando por M3: repos, namespaces y
worktrees; después files y git; después agentes. M2 queda para cuando un TUI real
(vim, htop, Claude Code) muestre límites del parser mínimo, o cuando haga falta
scrollback persistente con la pantalla exacta.

Cada dominio entra igual que la terminal: servicio nuevo en el `.proto`, casos de
uso en el daemon, y en la UI una interfaz de datos con dos implementaciones (mock
para tests y diseño, daemon para la app real), para no reescribir pantallas.

## Consecuencias

- La medición de salida de M1 (eco extremo a extremo p99 ≤ 16 ms, 60 fps) sigue
  pendiente y no bloquea.
- El render de la UI ya está en grilla de celdas: en M2 solo cambia de dónde salen
  las celdas (diffs del daemon en vez del parser en Dart).
- Persistencia: SQLite (`rusqlite`, `bundled`) en `<data_local_dir>/kumo/kumo.db`
  desde este hito, porque M4 la necesita igual.
