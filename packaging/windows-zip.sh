#!/usr/bin/env bash
# Builds Kumo for Windows and zips it, from Git Bash at the repo root:
#
#   packaging/windows-zip.sh 0.5.1  →  dist/Kumo-0.5.1-windows-x64.zip,
#                                      dist/Kumo-windows-x64.zip, dist/install.ps1
#
# The zip holds a Kumo folder: Kumo.exe (the UI), kumod.exe next to it (where
# the UI looks for it) and the VC++ runtime both need, which a fresh Windows
# may not have. RELEASE_REPO (owner/name) goes into install.ps1.
set -euo pipefail

version=${1:?usage: packaging/windows-zip.sh X.Y.Z}
# As on macOS: the commit count, so it only grows.
build=${BUILD:-$(git rev-list --count HEAD)}
repo=${RELEASE_REPO:-epiphany-sh/kumo}
app=kumo-ui/build/windows/x64/runner/Release

KUMO_VERSION=$version cargo build --release -p kumod
(cd kumo-ui && flutter pub get && flutter build windows --release --build-name="$version" --build-number="$build")

cp target/release/kumod.exe "$app/"
system32="$(cygpath -u "$SYSTEMROOT")/System32"
for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do
	cp "$system32/$dll" "$app/"
done

mkdir -p dist
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -r "$app" "$staging/Kumo"
rm -f "dist/Kumo-$version-windows-x64.zip"
(cd "$staging" && 7z a -tzip -bso0 "Kumo.zip" Kumo)
cp "$staging/Kumo.zip" "dist/Kumo-$version-windows-x64.zip"
# install.ps1 downloads the latest one by a fixed name.
cp "$staging/Kumo.zip" dist/Kumo-windows-x64.zip
sed -e "s|@RELEASE_REPO@|$repo|g" packaging/install.ps1.in > dist/install.ps1
echo "✓ dist/: Kumo-$version-windows-x64.zip, Kumo-windows-x64.zip, install.ps1"
