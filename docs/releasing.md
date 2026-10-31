# Releases y actualizaciones

Kumo se distribuye sin notarizar (no hay Developer ID). Igual se instala con
un comando y se actualiza con un click:

- **Primera instalación**: `install.sh` (lo que baja `curl` no queda en
  cuarentena, así que Gatekeeper no frena) o el cask de Homebrew (que le saca
  la cuarentena en `postflight`).
- **Updates**: Sparkle, adentro de la app. Revisa cada 6 h, descarga solo y
  avisa en la barra de arriba ("Restart to update"). Sin el click, instala al
  cerrar la app. Verifica cada update con una firma EdDSA propia.
- **El daemon**: el `kumod` que estaba corriendo sigue con el programa viejo;
  la UI lo reinicia sola cuando no hay terminales corriendo (`kumo.md` §7).
- **Keychain**: todas las versiones se firman con la misma identidad
  autofirmada ("Kumo Development"), así que su huella no cambia y el "Siempre
  permitir" de la Keychain sobrevive a los updates.

Los builds locales (`make app`, `make run`, `make dev`) no tienen feed: nunca
se reemplazan solos por la versión publicada.

## Dónde vive todo

`RELEASE_ORG` en el `Makefile` (hoy `epiphany-sh`) es la única fuente:

| Qué | Dónde |
|---|---|
| Código y releases | `github.com/epiphany-sh/kumo` |
| Appcast (lo que lee Sparkle) | `…/releases/latest/download/appcast.xml` |
| Instalador | `curl -fsSL https://github.com/epiphany-sh/kumo/releases/latest/download/install.sh \| sh` |
| Homebrew | `github.com/epiphany-sh/homebrew-kumo` → `brew install epiphany-sh/kumo/kumo` |

## Setup (una sola vez)

1. **Repos en GitHub**: la cuenta `epiphany-sh`, con `kumo` (este) y
   `homebrew-kumo`, los dos **públicos**: `install.sh`, brew y Sparkle bajan
   los releases sin autenticarse. Hecho.
2. **Clave de Sparkle**: `make sparkle-keys`. Guarda la privada en tu
   Keychain y escribe la pública en `packaging/sparkle-public-key`
   (commitealo). Para CI exportá la privada:
   `target/sparkle-2.10.0/bin/generate_keys -x sparkle-private-key`. Hecho.
   **Guardala bien**: si se pierde, las versiones publicadas no aceptan
   updates firmados con otra.
3. **Identidad de firma para CI**: exportá "Kumo Development" desde Acceso a
   Llaveros (certificado + clave privada) como `.p12` con contraseña.
   Revisá que venza dentro de muchos años: si la regenerás, la Keychain de
   cada usuario vuelve a pedir permiso una vez. Hecho: vence en 2036.

   Los valores de los secrets de abajo quedaron en `~/.kumo-release/` (un
   archivo por secret). Cargalos y guardá ese folder en un lugar seguro.
4. **Secrets del repo `kumo`** (Settings › Secrets › Actions):

   | Secret | Qué es |
   |---|---|
   | `KUMO_SIGNING_P12` | El `.p12` en base64 (`base64 -i kumo.p12 \| pbcopy`) |
   | `KUMO_SIGNING_PASSWORD` | Su contraseña |
   | `SPARKLE_PRIVATE_KEY` | El contenido de `sparkle-private-key` |
   | `HOMEBREW_TAP_TOKEN` | Un token fine-grained con permiso de escritura (Contents) sobre `homebrew-kumo` |

## Publicar una versión

**Sola, en cada merge a `main`.** Cuando el workflow `ci` termina en verde
sobre `main`, el workflow `release` publica la versión siguiente: buildea,
firma, arma el zip, el appcast y el `install.sh`, crea el release (y su tag)
en GitHub y actualiza el cask del tap.

El número lo calcula `packaging/next-version.sh`:

- `MAJOR.MINOR` sale de `version` en `[workspace.package]` de `Cargo.toml`.
- El patch es el siguiente al tag `vMAJOR.MINOR.*` más alto: `v0.1.0` →
  `0.1.1` → `0.1.2`…
- Para pasar a `0.2`, cambiá esa versión a `0.2.0` en un PR: el merge
  publica `0.2.0`.
- Nunca baja: si hay un tag más alto que `Cargo.toml` (uno hecho a mano),
  sigue desde ese. Con `v0.2.0` y `Cargo.toml` en `0.1.0`, sale `0.2.1`.

Los releases van de a uno. Si entran varios merges mientras uno se publica,
sale uno solo con todos. Si el build falla, no queda tag y el número se
vuelve a usar. Un commit que ya tiene tag no se publica de nuevo.

**A mano**, con el número que quieras:

```bash
git tag v0.2.0
git push origin v0.2.0
```

También se puede crear el release desde la web de GitHub: el workflow le
sube los archivos (zip, appcast, `install.sh`) y actualiza el cask. Mientras
corre (unos minutos), ese release queda como "Latest" sin appcast, y las apps
instaladas no encuentran updates hasta que termina.

El número de build (`CFBundleVersion`, lo que compara Sparkle) es la cantidad
de commits: siempre crece.

Para probarlo local sin publicar: `make release VERSION=0.2.0` deja todo en
`dist/` (firma el appcast con la clave de tu Keychain).
