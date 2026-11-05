#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:?Pass the app bundle}"
if [[ -z "${MACOS_SIGNING_IDENTITY:-}" ]]; then
  if [[ "${MACOS_REQUIRE_FIXED_SIGNING:-false}" == true ]]; then
    echo '::error::A release requires the fixed signing identity; refusing an ad-hoc fallback.' >&2
    exit 1
  fi
  codesign --force --deep --sign - "$APP"
  codesign --verify --deep --strict "$APP"
  echo 'Local/PR build: ad-hoc signed; not a production release.'
  exit 0
fi
EXPECTED="$(openssl x509 -in "$ROOT/ci/signing-certificate.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')"
test "$(printf '%s' "$MACOS_SIGNING_IDENTITY" | tr '[:upper:]' '[:lower:]')" = "$EXPECTED"
REQ="identifier \"com.teamhjd.pixelpin\" and certificate leaf = H\"$EXPECTED\""
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = com.teamhjd.pixelpin
# Preserve the vendor signatures of unchanged nested Sparkle components.
codesign --force --sign "$MACOS_SIGNING_IDENTITY" --keychain "$MACOS_SIGNING_KEYCHAIN" \
  --timestamp=none --requirements "=designated => $REQ" "$APP"
codesign --verify --deep --strict "$APP"
codesign --verify --strict -R "=$REQ" "$APP"
echo "Verified fixed signing identity: $EXPECTED"
