#!/bin/bash
set -euo pipefail
trap 'echo "::error file=macos/signing-test/prepare-pair.sh,line=$LINENO::Signing test preparation failed" >&2' ERR
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$RUNNER_TEMP/pixelpin-permission-test"
SOURCE_TAG=v1.2.2
SOURCE_ARCHIVE="Pixel-Pin-$SOURCE_TAG-macos-universal.zip"
mkdir -p "$WORK/source" "$ROOT/.build-arm64/artifacts/signing-test/Sparkle"
gh release download "$SOURCE_TAG" --repo "$GITHUB_REPOSITORY" --dir "$WORK/source" \
  --pattern "$SOURCE_ARCHIVE" --pattern "$SOURCE_ARCHIVE.sha256" --pattern appcast.xml
(cd "$WORK/source" && shasum -a 256 -c "$SOURCE_ARCHIVE.sha256")
# Use the same tools and checksum pinned by Sparkle's official 2.10.1 Package.swift.
gh release download 2.10.1 --repo sparkle-project/Sparkle --pattern Sparkle-for-Swift-Package-Manager.zip --dir "$WORK"
echo '4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a  Sparkle-for-Swift-Package-Manager.zip' > "$WORK/tools.sha256"
(cd "$WORK" && shasum -a 256 -c tools.sha256)
unzip -q "$WORK/Sparkle-for-Swift-Package-Manager.zip" -d "$ROOT/.build-arm64/artifacts/signing-test/Sparkle"
# Independently authenticate the released source archive with its public key.
python3 - "$WORK/source/appcast.xml" "$WORK/source/$SOURCE_ARCHIVE" "$WORK" <<'PY'
import base64, os, pathlib, sys, xml.etree.ElementTree as ET
feed, archive, work = map(pathlib.Path, sys.argv[1:])
item = ET.parse(feed).find('.//enclosure')
assert item is not None and item.get('url') == f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/releases/download/v1.2.2/{archive.name}"
assert int(item.get('length')) == archive.stat().st_size
key = base64.b64decode(os.environ['SPARKLE_ED_PUBLIC_KEY'], validate=True)
signature = base64.b64decode(item.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature'), validate=True)
assert len(key) == 32 and len(signature) == 64
(work / 'source-public.der').write_bytes(bytes.fromhex('302a300506032b6570032100') + key)
(work / 'source-signature.bin').write_bytes(signature)
PY
"$(brew --prefix openssl@3)/bin/openssl" pkeyutl -verify -pubin -inkey "$WORK/source-public.der" -keyform DER \
  -rawin -in "$WORK/source/$SOURCE_ARCHIVE" -sigfile "$WORK/source-signature.bin"
ditto -x -k "$WORK/source/$SOURCE_ARCHIVE" "$WORK/source/app"
SOURCE_APP="$WORK/source/app/Pixel Pin.app"
codesign --verify --deep --strict "$SOURCE_APP"
echo 'Released source bundle signature verified.'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")" = com.teamhjd.pixelpin
test "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$SOURCE_APP/Contents/Info.plist")" = "$SPARKLE_ED_PUBLIC_KEY"
FEED_TAG="macos-signing-test-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT-feed"
FEED="https://github.com/$GITHUB_REPOSITORY/releases/download/$FEED_TAG/appcast.xml"
REQ="identifier \"com.teamhjd.pixelpin\" and certificate leaf = H\"$MACOS_TEST_IDENTITY\""
for version in 1.2.3 1.2.4; do
  app="$WORK/$version/Pixel Pin.app"
  mkdir -p "$WORK/$version"
  ditto "$SOURCE_APP" "$app"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL $FEED" "$app/Contents/Info.plist"
  # Nested Sparkle components are unchanged and retain their valid signatures.
  echo "Signing test app $version with the shared temporary identity."
  codesign --force --sign "$MACOS_TEST_IDENTITY" --keychain "$MACOS_TEST_KEYCHAIN" --timestamp=none \
    --requirements "=designated => $REQ" "$app"
  codesign --verify --deep --strict "$app"
  codesign --verify --strict -R "=$REQ" "$app"
  codesign -d -r- "$app" > "$WORK/$version/identity.txt" 2>&1
  grep -q '^designated => ' "$WORK/$version/identity.txt"
done
OLD_REQ="$(sed -n 's/^designated => //p' "$WORK/1.2.3/identity.txt")"
NEW_REQ="$(sed -n 's/^designated => //p' "$WORK/1.2.4/identity.txt")"
test -n "$OLD_REQ"
test "$OLD_REQ" = "$NEW_REQ"
codesign --verify --strict -R "=$OLD_REQ" "$WORK/1.2.4/Pixel Pin.app"
codesign --verify --strict -R "=$NEW_REQ" "$WORK/1.2.3/Pixel Pin.app"
if codesign --verify --strict -R "=$OLD_REQ" "$SOURCE_APP" > /dev/null 2>&1; then
  echo '::error::The fixed requirement unexpectedly accepted the old ad-hoc app.'
  exit 1
fi
printf '%s\n' "$OLD_REQ" > "$WORK/signing-verification.txt"
echo 'PASS: both versions share the same certificate-bound identity and satisfy each other’s requirement; the ad-hoc source does not.' | tee -a "$WORK/signing-verification.txt"
echo "MACOS_TEST_WORK=$WORK" >> "$GITHUB_ENV"
echo "MACOS_TEST_FEED_TAG=$FEED_TAG" >> "$GITHUB_ENV"
