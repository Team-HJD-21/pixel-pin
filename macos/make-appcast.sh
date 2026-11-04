#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="${1:?Pass the macOS zip archive}"
TAG="${2:?Pass the release tag}"
REPOSITORY="${GITHUB_REPOSITORY:-Team-HJD-21/pixel-pin}"
TOOL="$(find "$ROOT/.build-arm64/artifacts" -type f -name generate_appcast -print -quit)"
test -x "$TOOL"
test -f "$ARCHIVE"
STAGING="$(mktemp -d "$ROOT/update-feed.XXXXXX")"
cp "$ARCHIVE" "$STAGING/"
# The signing key arrives on stdin, never as an argument or repository file.
"$TOOL" --ed-key-file - \
  --download-url-prefix "https://github.com/$REPOSITORY/releases/download/$TAG/" \
  "$STAGING"
python3 - "$STAGING/appcast.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
feed = ET.parse(sys.argv[1])
enclosures = feed.findall('.//enclosure')
signature = '{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'
if not enclosures or any(not item.get(signature) for item in enclosures):
    raise SystemExit('Appcast is missing signed update archives. Check the Sparkle key pair.')
PY
mkdir -p "$ROOT/update-feed"
cp "$STAGING/appcast.xml" "$ROOT/update-feed/appcast.xml"
