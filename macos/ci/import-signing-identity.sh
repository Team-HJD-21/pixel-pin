#!/bin/bash
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY_DIR="$RUNNER_TEMP/pixelpin-release-identity"
KEYCHAIN="$RUNNER_TEMP/pixelpin-release.keychain-db"
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
mkdir -p "$IDENTITY_DIR"
cp "$ROOT/ci/signing-certificate.pem" "$IDENTITY_DIR/certificate.pem"
python3 - "$IDENTITY_DIR/identity.p12" <<'PY'
import base64, os, pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(os.environ['MACOS_SIGNING_P12_BASE64'], validate=True))
PY
"$OPENSSL" pkcs12 -in "$IDENTITY_DIR/identity.p12" -passin env:MACOS_SIGNING_P12_PASSWORD \
  -clcerts -nokeys -out "$IDENTITY_DIR/imported.pem"
"$OPENSSL" x509 -in "$IDENTITY_DIR/imported.pem" -outform DER -out "$IDENTITY_DIR/imported.der"
"$OPENSSL" x509 -in "$IDENTITY_DIR/certificate.pem" -outform DER -out "$IDENTITY_DIR/expected.der"
cmp "$IDENTITY_DIR/imported.der" "$IDENTITY_DIR/expected.der"
"$OPENSSL" x509 -in "$IDENTITY_DIR/certificate.pem" -checkend 2592000 -noout
KEYCHAIN_PASSWORD="$("$OPENSSL" rand -base64 32)"
echo "::add-mask::$KEYCHAIN_PASSWORD"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"
security default-keychain -d user -s "$KEYCHAIN"
security import "$IDENTITY_DIR/identity.p12" -k "$KEYCHAIN" -P "$MACOS_SIGNING_P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null
# Trust is needed only while applying signatures on this disposable CI machine.
# The app's designated requirement pins the leaf certificate, not user trust.
sudo -n security add-trusted-cert -d -r trustRoot -p codeSign -k /Library/Keychains/System.keychain "$IDENTITY_DIR/certificate.pem"
FINGERPRINT="$("$OPENSSL" x509 -in "$IDENTITY_DIR/certificate.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"
security find-identity -v -p codesigning "$KEYCHAIN" | grep -qi "$FINGERPRINT"
{
  echo "MACOS_SIGNING_KEYCHAIN=$KEYCHAIN"
  echo "MACOS_SIGNING_IDENTITY=$FINGERPRINT"
} >> "$GITHUB_ENV"
rm -f "$IDENTITY_DIR/identity.p12" "$IDENTITY_DIR/imported.pem" "$IDENTITY_DIR/imported.der" "$IDENTITY_DIR/expected.der"
echo 'Imported the pinned, persistent Pixel Pin signing identity.'
