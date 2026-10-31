#!/bin/sh
# Which branch may merge into which, checked on every pull request:
#
#   main       ← release/X.Y.Z, above every v* tag (merging it releases X.Y.Z)
#   release/*  ← feature/… or fix/…
#
# Other bases have no rule. Usage: branch-policy.sh <base> <head>
set -eu

base=$1
head=$2
here=$(dirname "$0")

fail() {
	echo "$*" >&2
	exit 1
}

case $base in
main)
	case $head in
	release/*) ;;
	*) fail "Only a release/X.Y.Z branch merges into main, not '$head'. Open this one against a release branch." ;;
	esac
	version=$("$here/release-version.sh" "$head")
	if git tag -l "v$version" | grep -q .; then
		fail "v$version is already released: name the branch after the next version."
	fi
	highest=$(git tag -l 'v*' | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
		sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
	if [ -n "$highest" ]; then
		top=$(printf '%s\n%s\n' "$highest" "$version" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
		[ "$top" = "$version" ] || fail "v$version isn't above v$highest, the latest release."
	fi
	;;
release/*)
	case $head in
	feature/* | fix/*) ;;
	*) fail "A release branch takes feature/… or fix/… branches, not '$head'." ;;
	esac
	;;
esac
echo "ok: $head → $base"
