#!/bin/sh
# The version to release <commit> as (default HEAD): MAJOR.MINOR from the
# [workspace.package] version in its Cargo.toml, and the patch after the
# highest vMAJOR.MINOR.* tag (Cargo.toml's own patch when there's none yet).
# A tag with a higher MAJOR.MINOR (one made by hand) wins over Cargo.toml:
# versions never go down. Prints nothing when <commit> is already released
# (it has a v* tag).
#
#   Cargo.toml 0.1.0, tags v0.1.0 v0.1.1  →  0.1.2
#   Cargo.toml 0.2.0, tags up to v0.1.7   →  0.2.0
#   Cargo.toml 0.1.0, tags up to v0.2.0   →  0.2.1
set -eu

commit=${1:-HEAD}

if git tag --points-at "$commit" | grep -q '^v[0-9]'; then
	exit 0
fi

version=$(git show "$commit:Cargo.toml" | awk '
	/^\[workspace\.package\]/ { inside = 1; next }
	/^\[/ { inside = 0 }
	inside && /^version[ \t]*=/ { gsub(/[" \t]/, ""); sub(/^version=/, ""); print; exit }
')
case $version in
	[0-9]*.[0-9]*.[0-9]*) ;;
	*) echo "no MAJOR.MINOR.PATCH version in Cargo.toml's [workspace.package]: '$version'" >&2; exit 1 ;;
esac

minor=${version%.*}
patch=${version##*.}

# The highest MAJOR.MINOR tagged, if above Cargo.toml's.
highest=$(git tag -l 'v*' | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
	sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
if [ -n "$highest" ]; then
	tagged=${highest%.*}
	if [ "${tagged%.*}" -gt "${minor%.*}" ] ||
		{ [ "${tagged%.*}" -eq "${minor%.*}" ] && [ "${tagged#*.}" -gt "${minor#*.}" ]; }; then
		minor=$tagged
		patch=0
	fi
fi
last=$(git tag -l "v$minor.*" | sed "s/^v$minor\.//" | grep -E '^[0-9]+$' | sort -n | tail -n 1)
if [ -n "$last" ] && [ "$last" -ge "$patch" ]; then
	patch=$((last + 1))
fi
echo "$minor.$patch"
