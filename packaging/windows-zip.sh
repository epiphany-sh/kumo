#!/usr/bin/env bash
# Builds Kumo for Windows and zips it, from Git Bash at the repo root:
#
#   packaging/windows-zip.sh 0.5.1  →  dist/Kumo-0.5.1-windows-x64.zip, dist/install.ps1
#
# The zip holds a Kumo folder: Kumo.exe (the UI), kumod.exe next to it (where
# the UI looks for it) and the VC++ runtime both need, which a fresh Windows
# may not have, and install.ps1 to update it. RELEASE_REPO (owner/name)
# goes into install.ps1 and, with the version and Sparkle's public key (the
# one macOS embeds), into the app, which checks its updates' .sig with it.
#
# To try an update without publishing it (docs/releasing.md), a build can
# take other update settings, all baked in at build time:
#   SPARKLE_PUBLIC_KEY  base64 public key instead of packaging/sparkle-public-key
#   UPDATE_FEED         URL listing releases as GitHub's API does, instead of GitHub
#   UPDATE_PRERELEASES  1: GitHub prereleases and -beta versions count as updates
set -euo pipefail

version=${1:?usage: packaging/windows-zip.sh X.Y.Z}
# As on macOS: the commit count, so it only grows.
build=${BUILD:-$(git rev-list --count HEAD)}
repo=${RELEASE_REPO:-epiphany-sh/kumo}
app=kumo-ui/build/windows/x64/runner/Release
update_key=${SPARKLE_PUBLIC_KEY:-$(cat packaging/sparkle-public-key)}
update_defines=()
if [ -n "${UPDATE_FEED:-}" ]; then update_defines+=(--dart-define=KUMO_UPDATE_FEED="$UPDATE_FEED"); fi
if [ "${UPDATE_PRERELEASES:-}" = 1 ]; then update_defines+=(--dart-define=KUMO_UPDATE_PRERELEASES=true); fi

KUMO_VERSION=$version cargo build --release -p kumod
(cd kumo-ui && flutter pub get && flutter build windows --release --build-name="$version" --build-number="$build" \
	--dart-define=KUMO_VERSION="$version" --dart-define=KUMO_RELEASE_REPO="$repo" --dart-define=KUMO_UPDATE_KEY="$update_key" ${update_defines[@]+"${update_defines[@]}"})

cp target/release/kumod.exe "$app/"
system32="$(cygpath -u "$SYSTEMROOT")/System32"
for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do
	cp "$system32/$dll" "$app/"
done

mkdir -p dist
sed -e "s|@RELEASE_REPO@|$repo|g" packaging/install.ps1.in > dist/install.ps1
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -r "$app" "$staging/Kumo"
# Kumo updates itself with the install.ps1 of the version it downloaded
# (install.ps1 -From).
cp dist/install.ps1 "$staging/Kumo/install.ps1"
rm -f "dist/Kumo-$version-windows-x64.zip"
# 7z where there is one (GitHub's runners); else Windows' own bsdtar, which
# writes zips too.
if command -v 7z > /dev/null; then
	(cd "$staging" && 7z a -tzip -bso0 Kumo.zip Kumo)
else
	(cd "$staging" && "$system32/tar.exe" -a -cf Kumo.zip Kumo)
fi
cp "$staging/Kumo.zip" "dist/Kumo-$version-windows-x64.zip"
sha256sum "dist/Kumo-$version-windows-x64.zip" | cut -d' ' -f1 > "dist/Kumo-$version-windows-x64.zip.sha256"
echo "✓ dist/: Kumo-$version-windows-x64.zip and its .sha256, install.ps1"
