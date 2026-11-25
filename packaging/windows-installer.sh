#!/usr/bin/env bash
# Builds Kumo's Windows installer from the zip packaging/windows-zip.sh made,
# from Git Bash at the repo root:
#
#   packaging/windows-installer.sh 0.10.0  →  dist/Kumo-0.10.0-windows-x64-setup.exe and its .sha256
#
# The installer holds exactly what the zip does (packaging/windows/kumo.iss).
# Needs Inno Setup 6: ISCC on PATH, or where its installer puts it (winget,
# choco). RELEASE_REPO (owner/name) goes into the installer's links. Signing
# (the .sig the app checks) is packaging/sign-ed25519.sh's.
set -euo pipefail

version=${1:?usage: packaging/windows-installer.sh X.Y.Z[-pre]}
repo=${RELEASE_REPO:-epiphany-sh/kumo}
zip=dist/Kumo-$version-windows-x64.zip
setup=dist/Kumo-$version-windows-x64-setup.exe

if [ ! -f "$zip" ]; then
	echo "$zip is missing: run packaging/windows-zip.sh $version first" >&2
	exit 1
fi

find_iscc() {
	command -v iscc || command -v ISCC || {
		local dir
		for dir in "${LOCALAPPDATA:-}/Programs/Inno Setup 6" "${PROGRAMFILES:-}/Inno Setup 6" "${PROGRAMFILES:-} (x86)/Inno Setup 6" "C:/Program Files (x86)/Inno Setup 6"; do
			if [ -n "$dir" ] && [ -f "$dir/ISCC.exe" ]; then
				echo "$dir/ISCC.exe"
				return
			fi
		done
	}
}

iscc=$(find_iscc || true)
# CI sets INSTALL_INNO_SETUP=1: choco only runs when the runner image doesn't
# already have Inno Setup, so a Chocolatey outage can't fail the build.
if [ -z "$iscc" ] && [ "${INSTALL_INNO_SETUP:-}" = 1 ]; then
	echo "Inno Setup not found: installing it with choco"
	choco install innosetup -y --no-progress
	iscc=$(find_iscc || true)
fi
if [ -z "$iscc" ]; then
	echo "Inno Setup 6 (ISCC.exe) not found: winget install --id JRSoftware.InnoSetup -e --scope user" >&2
	exit 1
fi

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
# 7z where there is one (GitHub's runners); else Windows' own bsdtar.
if command -v 7z > /dev/null; then
	7z x -bso0 -o"$staging" "$zip"
else
	"$(cygpath -u "$SYSTEMROOT")/System32/tar.exe" -xf "$(cygpath -w "$zip")" -C "$(cygpath -w "$staging")"
fi
if [ ! -f "$staging/Kumo/Kumo.exe" ]; then
	echo "$zip has no Kumo/Kumo.exe" >&2
	exit 1
fi

rm -f "$setup" "$setup.sha256" "$setup.sig"
# ISCC takes /D...: Git Bash must not turn them into paths.
MSYS2_ARG_CONV_EXCL='*' "$iscc" /Qp \
	"/DAppVersion=$version" \
	"/DSourceDir=$(cygpath -w "$staging/Kumo")" \
	"/DOutputDir=$(cygpath -w "$PWD/dist")" \
	"/DReleaseRepo=$repo" \
	"$(cygpath -w "$PWD/packaging/windows/kumo.iss")"

sha256sum "$setup" | cut -d' ' -f1 > "$setup.sha256"
echo "✓ $setup and its .sha256"
