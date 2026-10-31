#!/bin/sh
# X.Y.Z of a release/X.Y.Z branch; fails for any other name.
#
#   release-version.sh release/0.3.0  →  0.3.0
set -eu

branch=${1:-}
version=${branch#release/}
if [ "$version" = "$branch" ] || ! echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
	echo "'$branch' isn't a release branch: release/X.Y.Z" >&2
	exit 1
fi
echo "$version"
