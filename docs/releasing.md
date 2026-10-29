# Releases y actualizaciones

Kumo se distribuye sin notarizar (no hay Developer ID). Igual se instala con
un comando y se actualiza con un click:

- **Primera instalación**: `install.sh` (lo que baja `curl` no queda en
  cuarentena, así que Gatekeeper no frena) o el cask de Homebrew (que le saca
  la cuarentena en `postflight`).
- **Updates**: Sparkle, adentro de la app. Revisa cada 6 h, descarga solo y
  avisa en la barra de arriba ("Kumo 0.2 · Restart"). Sin el click, instala al
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

1. **Org y repos en GitHub**: la org `epiphany-sh`, el repo `kumo` (este) y
   el repo `homebrew-kumo` (vacío, con un README alcanza).
2. **Clave de Sparkle**: `make sparkle-keys`. Guarda la privada en tu
   Keychain y escribe la pública en `packaging/sparkle-public-key`
   (commitealo). Para CI exportá la privada:
   `target/sparkle-2.10.0/bin/generate_keys -x sparkle-private-key`.
   **Guardala bien**: si se pierde, las versiones publicadas no aceptan
   updates firmados con otra.
3. **Identidad de firma para CI**: exportá "Kumo Development" desde Acceso a
   Llaveros (certificado + clave privada) como `.p12` con contraseña.
   Revisá que venza dentro de muchos años: si la regenerás, la Keychain de
   cada usuario vuelve a pedir permiso una vez.
4. **Secrets del repo `kumo`** (Settings › Secrets › Actions):

   | Secret | Qué es |
   |---|---|
   | `KUMO_SIGNING_P12` | El `.p12` en base64 (`base64 -i kumo.p12 \| pbcopy`) |
   | `KUMO_SIGNING_PASSWORD` | Su contraseña |
   | `SPARKLE_PRIVATE_KEY` | El contenido de `sparkle-private-key` |
   | `HOMEBREW_TAP_TOKEN` | Un token fine-grained con permiso de escritura (Contents) sobre `homebrew-kumo` |

## Publicar una versión

```bash
git tag v0.2.0
git push origin v0.2.0
```

El workflow `release` buildea, firma, arma el zip, el appcast y el
`install.sh`, crea el release en GitHub y actualiza el cask del tap. El
número de build (`CFBundleVersion`, lo que compara Sparkle) es la cantidad de
commits: siempre crece.

Para probarlo local sin publicar: `make release VERSION=0.2.0` deja todo en
`dist/` (firma el appcast con la clave de tu Keychain).
