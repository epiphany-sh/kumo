#!/bin/sh
# The appcast Sparkle reads: the latest release only.
#
#   appcast.sh <version> <build> <zip>  >  appcast.xml
#
# SIGN_UPDATE: Sparkle's sign_update. It signs with the key in the login
# Keychain (make sparkle-keys), or SPARKLE_KEY_FILE's (CI).
# RELEASE_REPO: where the zip is published (owner/name).
set -eu

version=$1
build=$2
zip=$3
: "${RELEASE_REPO:?}"

if [ -n "${SPARKLE_KEY_FILE:-}" ]; then
	signature=$("${SIGN_UPDATE:-sign_update}" --ed-key-file "$SPARKLE_KEY_FILE" "$zip")
else
	signature=$("${SIGN_UPDATE:-sign_update}" "$zip")
fi
case $signature in
*sparkle:edSignature=*) ;;
*) echo "sign_update said: $signature" >&2; exit 1 ;;
esac

url="https://github.com/$RELEASE_REPO/releases/download/v$version/$(basename "$zip")"
date=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Kumo</title>
    <item>
      <title>Kumo $version</title>
      <pubDate>$date</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/$RELEASE_REPO/releases/tag/v$version</sparkle:releaseNotesLink>
      <enclosure url="$url" type="application/octet-stream" $signature />
    </item>
  </channel>
</rss>
XML
