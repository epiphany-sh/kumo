# Kumo: reglas para agentes

## Ramas y pull requests

Las ramas siguen un camino fijo y el check `branch-policy` de `ci`
(`packaging/branch-policy.sh`) rechaza cualquier otro. El detalle está en
[docs/releasing.md](docs/releasing.md).

```
feature/…  ─┐
feat/…     ─┤
fix/…      ─┴─▶  release/X.Y.Z  ──▶  main  ──▶  vX.Y.Z publicada
```

- **El trabajo va en `feature/<tema>`, `feat/<tema>` o `fix/<tema>`.**
  Ningún otro nombre pasa el check (tampoco `claude/…`). Si la sesión
  arrancó en otra rama,
  pusheá el commit con el nombre correcto:
  `git push origin HEAD:refs/heads/fix/<tema>`.
- **El PR va contra la `release/X.Y.Z` abierta, nunca contra `main`.** A
  `main` solo entran releases.
- **Partí de `origin`, no del `main` local**, que puede estar atrasado o
  tener commits que ya entraron por otro PR: cortá la rama desde
  `origin/release/X.Y.Z` (o `origin/main` si no hay release abierta).
- **Release abierta** es una `release/X.Y.Z` en `origin` mayor que el último
  tag `v*`:

  ```bash
  git fetch origin --tags
  git ls-remote --heads origin 'release/*'
  git tag -l 'v*' --sort=-v:refname | head -1
  ```

  Si no hay, creala desde `origin/main` con el patch siguiente al último tag
  (`git push origin origin/main:refs/heads/release/X.Y.Z`). Si el cambio
  pide un minor o un major, preguntá antes.
- **`release/X.Y.Z` → `main` publica la versión.** No abras ni mergees ese
  PR sin que lo pida el usuario.
- Nada se pushea directo a `release/*` ni a `main`: todo entra por PR.

## Performance

Kumo queda abierto horas con agentes escribiendo sin parar: todo lo que se
dispara por evento o por frame se multiplica. Antes de cerrar una feature,
revisá [docs/performance.md](docs/performance.md). Lo mínimo:

- **Sin animaciones infinitas a vsync**: timer a baja frecuencia,
  `RepaintBoundary`, y se paran si no se ven o si hay "reducir movimiento".
- **Lo oculto no dibuja**: nada de snapshots, `setState` ni frames para
  pantallas o terminales que no están en pantalla.
- **Rebuilds acotados**: escuchá solo lo que mostrás; lo derivado de la
  config se cachea y tiene `==`.
- **Eventos de archivos por el scheduler** (`workspace/schedule.rs`):
  debounce, piso de 3 s entre corridas, single flight, solo el worktree que
  cambió. Nunca un segundo watcher ni un `sleep` corto en loop.
- **Git barato**: pocos procesos, resultados cacheados por oid/mtime,
  `GIT_OPTIONAL_LOCKS=0`.
- **Respetá la presencia de la ventana**: sin foco, más lento; oculta, en
  pausa.
- **Timers testeados con tiempo falso**, nunca con sleeps reales.
