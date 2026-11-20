#!/usr/bin/env bash
# Signs a file with Sparkle's ed25519 key, the way Kumo for Windows checks
# its updates:
#
#   SPARKLE_PRIVATE_KEY=… packaging/sign-ed25519.sh <file>  →  <file>.sig
#
# <file>.sig is the base64 of the raw 64-byte ed25519 signature over the
# file's bytes (what Sparkle's sign_update prints as edSignature).
# SPARKLE_PRIVATE_KEY: what `generate_keys -x` exports, the base64 of the
# 32-byte seed (a 64-byte seed + public key works too; Sparkle's older
# 96-byte format doesn't hold the seed, so it can't sign here).
# SPARKLE_PUBLIC_KEY: base64 of the 32-byte public key the signature must
# verify against; packaging/sparkle-public-key, which the apps embed, if
# unset. A key that doesn't match fails here instead of shipping a .sig no
# app accepts.
set -euo pipefail

file=${1:?usage: packaging/sign-ed25519.sh <file>}
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is not set}"
public=${SPARKLE_PUBLIC_KEY:-$(cat "$(dirname "$0")/sparkle-public-key")}

umask 077
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

hex() { printf "$(printf '%s' "$1" | sed 's/../\\x&/g')"; }

printf '%s' "$SPARKLE_PRIVATE_KEY" | tr -d ' \r\n' | openssl base64 -d -A > "$tmp/secret"
case $(wc -c < "$tmp/secret" | tr -d ' ') in
32 | 64) ;;
*) echo "SPARKLE_PRIVATE_KEY must decode to a 32-byte seed (or 64 bytes: seed + public key)" >&2; exit 1 ;;
esac
# PKCS#8 for an ed25519 seed, and SPKI for a public key: fixed DER headers
# followed by the 32 key bytes.
{ hex 302e020100300506032b657004220420; head -c 32 "$tmp/secret"; } > "$tmp/key.der"
rm "$tmp/secret"
printf '%s' "$public" | tr -d ' \r\n' | openssl base64 -d -A > "$tmp/public"
if [ "$(wc -c < "$tmp/public" | tr -d ' ')" != 32 ]; then
	echo "The public key must decode to 32 bytes" >&2
	exit 1
fi
{ hex 302a300506032b6570032100; cat "$tmp/public"; } > "$tmp/public.der"

openssl pkeyutl -sign -rawin -keyform DER -inkey "$tmp/key.der" -in "$file" -out "$tmp/sig"
rm "$tmp/key.der"
if ! openssl pkeyutl -verify -rawin -pubin -keyform DER -inkey "$tmp/public.der" \
	-in "$file" -sigfile "$tmp/sig" > /dev/null; then
	echo "The signature doesn't verify against the public key: SPARKLE_PRIVATE_KEY isn't its pair" >&2
	exit 1
fi
openssl base64 -A -in "$tmp/sig" > "$file.sig"
echo "✓ $file.sig"
