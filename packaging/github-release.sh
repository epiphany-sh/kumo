#!/usr/bin/env bash
# Adds files to the GitHub release vX.Y.Z, creating it (and its tag, on SHA)
# if it isn't there yet. macOS and Windows publish on their own, whichever
# finishes first creates it:
#
#   github-release.sh --latest X.Y.Z SHA files…   macOS: it becomes "Latest"
#   github-release.sh X.Y.Z SHA files…            Windows: "Latest" untouched
#
# "Latest" is what Sparkle's appcast, install.sh and brew download from, so
# only a release with the macOS files gets it. Needs GH_TOKEN and GH_REPO.
set -euo pipefail

latest=false
if [ "${1:-}" = --latest ]; then
	latest=true
	shift
fi
version=${1:?usage: github-release.sh [--latest] X.Y.Z SHA files…}
sha=${2:?usage: github-release.sh [--latest] X.Y.Z SHA files…}
shift 2

# Both jobs can try to create it at once: the one that loses uploads.
if ! gh release view "v$version" >/dev/null 2>&1 &&
	gh release create "v$version" --target "$sha" --title "Kumo $version" --generate-notes \
		--latest="$latest" "$@"; then
	exit 0
fi
gh release upload "v$version" "$@" --clobber
if [ "$latest" = true ]; then
	gh release edit "v$version" --latest
fi
