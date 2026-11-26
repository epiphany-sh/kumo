# Releases y actualizaciones

Kumo se distribuye sin notarizar (no hay Developer ID). Igual se instala con
un comando y se actualiza con un click:

- **Primera instalación**: `install.sh` (lo que baja `curl` no queda en
  cuarentena, así que Gatekeeper no frena) o el cask de Homebrew (que le saca
  la cuarentena en `postflight`).
- **Updates**: Sparkle, adentro de la app. Revisa cada hora, descarga solo y
  avisa en la barra de arriba ("Restart to update"). Sin el click, instala al
  cerrar la app. Verifica cada update con una firma EdDSA propia.
- **El daemon**: el `kumod` que estaba corriendo sigue con el programa viejo;
  la UI lo reinicia sola cuando no hay terminales corriendo (`kumo.md` §7).
- **Keychain**: todas las versiones se firman con la misma identidad
  autofirmada ("Kumo Development"), así que su huella no cambia y el "Siempre
  permitir" de la Keychain sobrevive a los updates.

Los builds locales (`make app`, `make run`, `make dev`) no tienen feed: nunca
se reemplazan solos por la versión publicada.

**Windows** sale en el mismo release. Los `.exe` no llevan firma de código
(Authenticode), pero el instalador y el zip sí llevan una firma ed25519 hecha
con la misma clave de Sparkle (`Kumo-X.Y.Z-windows-x64-setup.exe.sig`,
`Kumo-X.Y.Z-windows-x64.zip.sig`):

- **Instalación**: `Kumo-X.Y.Z-windows-x64-setup.exe`, un instalador de Inno
  Setup (`packaging/windows/kumo.iss`) por usuario, sin pedir admin. Instala
  en `%LOCALAPPDATA%\Programs\Kumo`, crea el acceso en el menú Inicio y
  registra el desinstalador en "Aplicaciones instaladas" (HKCU). Su `AppId`
  no cambia nunca: así Windows sabe que una versión nueva es la misma app.
  `install.ps1` sigue funcionando (baja el zip del release más nuevo que lo
  tenga, no de "Latest", ver abajo) e instala en la misma carpeta, así que
  uno actualiza lo que instaló el otro. Ninguno de los dos verifica la firma
  al instalar a mano: `install.ps1` compara el zip con su `.sha256`.
- **Updates**: igual que Sparkle. La app consulta los releases de GitHub al
  abrir (a los 30 s) y después cada hora, mientras "Download updates
  automatically" esté prendido; Settings › General › "Check for Updates…"
  consulta en el momento. Baja el `-setup.exe` más nuevo, verifica el `.sig`
  contra la clave pública de Sparkle que trae adentro
  (`--dart-define=KUMO_UPDATE_KEY`) y que el instalador diga ser esa versión
  (su `ProductVersion`), y avisa "Restart to update". Con el click corre el
  instalador en silencio (`/VERYSILENT /SUPPRESSMSGBOXES /NORESTART
  /WAITPID=<pid> /RELAUNCH`), que espera a que Kumo se cierre, instala y lo
  vuelve a abrir. Sin el click, instala al cerrar Kumo (sin reabrirlo). Si
  falla, lo anota en `%LOCALAPPDATA%\Kumo\updates\update.log` y la app lo
  muestra en Settings la próxima vez; el log completo del instalador queda en
  `setup.log`, al lado.
- **Solo los builds de release se actualizan**: los que arma
  `packaging/windows-zip.sh` (con versión, repo y clave por `--dart-define`),
  instalados en `%LOCALAPPDATA%\Programs\Kumo`. Un build de debug, uno de
  canal (`make sandbox`) o uno corriendo desde otra carpeta nunca consultan.
- **El daemon**: un `kumod.exe` corriendo (y las DLL que cargó) no se puede
  pisar ni borrar, pero sí renombrar. El instalador renombra `kumod.exe` y
  las DLL de la carpeta a `<nombre>.<id>.old` antes de copiar; si la
  instalación falla, los devuelve a su nombre. Las ventanas de Kumo abiertas
  se cierran (Restart Manager, que solo mira archivos de la UI: nunca cierra
  `kumod`). El viejo sigue corriendo con sus terminales y la UI lo reinicia
  sobre el nuevo como en macOS. Los `.old` se borran en la próxima
  instalación, si ya no corren. `install.ps1` hace lo mismo con todo lo que
  hay en la carpeta, menos el desinstalador (`unins000.*`);
  `packaging/tests/install-swap.ps1` lo prueba en CI.
- **El zip** (`packaging/windows-zip.sh`) trae `Kumo.exe`, `kumod.exe` y el
  runtime de VC++ que necesitan los dos. El instalador
  (`packaging/windows-installer.sh`) se arma desde ese zip, así que trae lo
  mismo. El zip sigue firmado porque el updater de Kumo 0.9.0 instala zips.
- **La firma**: `packaging/sign-ed25519.sh` firma con `openssl` (el
  `sign_update` de Sparkle es solo para macOS). `SPARKLE_PRIVATE_KEY` es lo
  que exporta `generate_keys -x`: la semilla ed25519 de 32 bytes en base64.
  El `.sig` es la firma ed25519 cruda (64 bytes) en base64, lo mismo que
  Sparkle llama `edSignature`. Antes de escribirlo, el script la verifica
  contra `packaging/sparkle-public-key`, así una clave equivocada falla en CI
  y no en las máquinas de la gente.

## Dónde vive todo

`RELEASE_ORG` en el `Makefile` (hoy `epiphany-sh`) es la única fuente:

| Qué | Dónde |
|---|---|
| Código y releases | `github.com/epiphany-sh/kumo` |
| Appcast (lo que lee Sparkle) | `…/releases/latest/download/appcast.xml` |
| Instalador | `curl -fsSL https://github.com/epiphany-sh/kumo/releases/latest/download/install.sh \| sh` |
| Homebrew | `github.com/epiphany-sh/homebrew-kumo` → `brew install epiphany-sh/kumo/kumo` |
| Instalador de Windows | `Kumo-X.Y.Z-windows-x64-setup.exe` en `github.com/epiphany-sh/kumo/releases` |
| Instalador de Windows (PowerShell) | `irm https://github.com/epiphany-sh/kumo/releases/latest/download/install.ps1 \| iex` |

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

Las ramas siguen un camino fijo, y lo hace cumplir el check `branch-policy` de
`ci` (`packaging/branch-policy.sh`), obligatorio para mergear:

```
feature/…  ─┐
feat/…     ─┤
fix/…      ─┴─▶  release/X.Y.Z  ──▶  main  ──▶  vX.Y.Z publicada
```

1. **Abrí la release** desde `main`, con el número que va a tener:
   `git switch -c release/0.3.0 origin/main && git push -u origin release/0.3.0`.
   El número tiene que ser mayor que el último tag.
2. **Los cambios entran por PR** a esa rama, desde `feature/…`, `feat/…` o `fix/…`.
   Nada se pushea directo a una `release/*`: pasan por PR y `ci`, igual que
   `main`. Los checks obligatorios corren en Linux y Windows (`branch-policy`,
   `fmt`, `clippy (…)`, `test (…)`, `ui`); el job `macos` corre lo mismo en
   macOS pero no bloquea, porque los runners macOS arm64 de GitHub a veces
   pasan días sin capacidad.
3. **Probá Your agents con las CLIs reales** antes de mergear la release: los
   tests de siempre usan CLIs falsas y no ven si una cambió sus flags o su
   salida. Necesita cada CLI instalada y con sesión, y gasta un poco de cuota:
   `cargo test -p kumod --test real_clis -- --ignored --test-threads=1`.
4. **Mergeá la release a `main`** con un PR (`release/0.3.0` → `main`). Es lo
   único que entra a `main`. Con el merge, el workflow `release` publica
   `0.3.0`: buildea, firma, arma el zip, el appcast y el `install.sh` en
   macOS; el instalador, el zip y el `install.ps1` en Windows. Cada uno sube lo suyo al release
   (el primero que termina lo crea, con su tag); macOS además actualiza el
   cask del tap.

   **Windows no espera a macOS**, porque los runners macOS de GitHub a veces
   pasan días sin capacidad. Por eso solo macOS marca el release como
   "Latest", que es de donde bajan Sparkle, `install.sh` y brew: si Windows
   publica primero, el release queda sin "Latest" hasta que termina macOS, y
   las Macs siguen viendo la versión anterior. `install.ps1` viaja con los
   dos y busca el zip de Windows más nuevo, esté o no en "Latest"
   (`packaging/github-release.sh`); el updater de Windows hace lo mismo con
   el `-setup.exe`.

Los releases van de a uno. Si fallan los dos builds, no queda tag:
re-correlo desde Actions. Si falla uno solo, el otro ya creó el tag y el
número quedó usado: re-corré el job que falló (no el workflow entero, que
vería el tag y no haría nada).

**Solo un merge a `main` publica.** Un tag no dispara nada, porque ejecutaría
el workflow de su propio commit, sin pasar por el PR. El ruleset `release tags`
impide mover o borrar los `v*` ya creados. Crearlos no se puede bloquear: en una
cuenta personal, GitHub no acepta a Actions como excepción de un ruleset, y el
workflow necesita crear el tag.

## Qué protege cada paso

Compilar ejecuta código de todas las dependencias, así que el workflow lo hace
aparte:

| Job | Secretos | Token | Qué hace |
|---|---|---|---|
| `macos-build`, `windows-build` | Ninguno | Solo lectura | Compilan y suben el resultado como artifact |
| `macos-publish`, `windows-publish` | Los de firma y el tap | Escritura | Firman, empaquetan y publican, sin compilar |

`make app` sigue haciendo todo junto en local: es `make bundle` y `make sign`.

- **Acciones y descargas**: las acciones van fijadas por SHA, y Sparkle se
  verifica contra `SPARKLE_SHA256`. Para actualizar una, cambiá el SHA y el
  comentario de versión.
- **Hardened runtime**: `Kumo.app` y `kumod` se firman con `--options runtime`.
  La app necesita `disable-library-validation` porque sus frameworks no llevan
  Team ID (no hay Developer ID).
- **Checksums**: `install.sh` e `install.ps1` comparan la descarga con el
  `.sha256` del mismo release. Eso detecta una descarga corrupta o incompleta,
  pero **no** protege si el release entero está comprometido: para eso están
  las atestaciones de build (`gh attestation verify <zip> --repo epiphany-sh/kumo`).
- **Dependencias**: el job `audit` de `ci` corre `cargo audit` en cada PR. No es
  obligatorio. Dependabot no puede abrir PRs acá porque `branch-policy` rechaza
  sus ramas, así que solo se usan sus alertas.
- **Si se filtra la clave de Sparkle**: las versiones publicadas (de macOS y de
  Windows) no aceptan otra clave, así que rotarla requiere publicar primero una versión firmada con la
  vieja que incluya la pública nueva.

El número de build (`CFBundleVersion`, lo que compara Sparkle) es la cantidad
de commits: siempre crece.

Para probarlo local sin publicar: `make release VERSION=0.2.0` deja todo en
`dist/` (firma el appcast con la clave de tu Keychain). En Windows, desde Git
Bash: `make windows-installer VERSION=0.2.0` deja el zip y el
`-setup.exe` en `dist/` (necesita Inno Setup 6:
`winget install --id JRSoftware.InnoSetup -e --scope user`). Con
`SPARKLE_KEY_FILE=<archivo con la clave privada>` también lo firma; sin
eso, avisa y no firma: se instala a mano, pero ningún Kumo lo toma como
update. Cada PR también buildea la app y el instalador de Windows (job
`windows-app` de `ci`, no obligatorio) y deja la app como artifact una
semana, para probarla sin publicar.

### Probar el updater de Windows con una beta

Sin tocar los releases de verdad: un par de claves de prueba, un feed local
y dos betas. Desde Git Bash, en la raíz del repo:

1. **Claves de prueba** (nunca la de Sparkle):

   ```bash
   mkdir -p target/update-test && cd target/update-test
   openssl genpkey -algorithm ed25519 -outform DER -out key.der
   tail -c 32 key.der | openssl base64 -A > private-key   # la semilla, como generate_keys -x
   openssl pkey -inform DER -in key.der -pubout -outform DER | tail -c 32 | openssl base64 -A > public-key
   cd ../..
   ```

2. **La beta 1, apuntando al feed local**. Las variables quedan fijas en el
   build (`--dart-define`), no se pueden cambiar con la app instalada:

   ```bash
   export SPARKLE_PUBLIC_KEY=$(cat target/update-test/public-key)
   export UPDATE_FEED=http://127.0.0.1:8765/releases.json
   export UPDATE_PRERELEASES=1     # sin esto, una beta solo se actualiza a releases
   make windows-installer VERSION=0.10.0-beta.1 SPARKLE_KEY_FILE=target/update-test/private-key
   ```

   Instalala: doble click en `dist/Kumo-0.10.0-beta.1-windows-x64-setup.exe`
   (o con `/VERYSILENT`).

3. **La beta 2, servida en el feed local**, con las mismas variables:

   ```bash
   make windows-installer VERSION=0.10.0-beta.2 SPARKLE_KEY_FILE=target/update-test/private-key
   mkdir -p target/update-test/feed
   cp dist/Kumo-0.10.0-beta.2-windows-x64-setup.exe* target/update-test/feed/
   cat > target/update-test/feed/releases.json <<'EOF'
   [{"tag_name": "v0.10.0-beta.2", "draft": false, "prerelease": true, "assets": [
     {"name": "Kumo-0.10.0-beta.2-windows-x64-setup.exe", "browser_download_url": "http://127.0.0.1:8765/Kumo-0.10.0-beta.2-windows-x64-setup.exe"},
     {"name": "Kumo-0.10.0-beta.2-windows-x64-setup.exe.sig", "browser_download_url": "http://127.0.0.1:8765/Kumo-0.10.0-beta.2-windows-x64-setup.exe.sig"},
     {"name": "Kumo-0.10.0-beta.2-windows-x64-setup.exe.sha256", "browser_download_url": "http://127.0.0.1:8765/Kumo-0.10.0-beta.2-windows-x64-setup.exe.sha256"}]}]
   EOF
   py -3 -m http.server 8765 --bind 127.0.0.1 --directory target/update-test/feed
   ```

4. En la beta 1 instalada: Settings › General › **Check for Updates…**.
   Pasa por "Downloading…" y queda "Kumo 0.10.0-beta.2 is ready". **Restart
   to Update**: Kumo se cierra, el instalador corre en silencio y abre la
   beta 2 (Settings › About, o `update.log` en
   `%LOCALAPPDATA%\Kumo\updates`).

Para desinstalar: "Aplicaciones instaladas" › Kumo, o
`%LOCALAPPDATA%\Programs\Kumo\unins000.exe /VERYSILENT`. Las betas de
prueba usan la clave de prueba: no aceptan updates firmados con la de
Sparkle, así que después instalá la versión publicada encima.
