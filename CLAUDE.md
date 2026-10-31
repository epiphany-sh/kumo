# Kumo: reglas para agentes

## Ramas y pull requests

Las ramas siguen un camino fijo y el check `branch-policy` de `ci`
(`packaging/branch-policy.sh`) rechaza cualquier otro. El detalle está en
[docs/releasing.md](docs/releasing.md).

```
feature/…  ─┐
fix/…      ─┴─▶  release/X.Y.Z  ──▶  main  ──▶  vX.Y.Z publicada
```

- **El trabajo va en `feature/<tema>` o `fix/<tema>`.** Ningún otro nombre
  pasa el check (tampoco `claude/…`). Si la sesión arrancó en otra rama,
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
