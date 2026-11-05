#!/bin/bash
set -euo pipefail
umask 077
IDENTITY_DIR="$RUNNER_TEMP/pixelpin-test-identity"
mkdir -p "$IDENTITY_DIR"
KEYCHAIN="$RUNNER_TEMP/pixelpin-signing-test.keychain-db"
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
KEYCHAIN_PASSWORD="$("$OPENSSL" rand -base64 32)"
MACOS_EPHEMERAL_P12_PASSWORD="$("$OPENSSL" rand -base64 32)"
export MACOS_EPHEMERAL_P12_PASSWORD
echo "::add-mask::$KEYCHAIN_PASSWORD"
echo "::add-mask::$MACOS_EPHEMERAL_P12_PASSWORD"
# One ephemeral private identity is shared by both versions in this test only.
# Nothing is imported from the user's machine or stored in repository secrets.
"$OPENSSL" req -x509 -newkey rsa:3072 -sha256 -days 30 -noenc \
  -keyout "$IDENTITY_DIR/key.pem" -out "$IDENTITY_DIR/certificate.pem" \
  -subj '/CN=Pixel Pin Permission Test/O=TeamHJD' \
  -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
  -addext 'keyUsage=critical,digitalSignature,keyCertSign' \
  -addext 'extendedKeyUsage=codeSigning' -addext 'subjectKeyIdentifier=hash' 2> /dev/null
"$OPENSSL" pkcs12 -export -inkey "$IDENTITY_DIR/key.pem" -in "$IDENTITY_DIR/certificate.pem" \
  -out "$IDENTITY_DIR/identity.p12" -name 'Pixel Pin Permission Test' \
  -passout env:MACOS_EPHEMERAL_P12_PASSWORD -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -iter 100000
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$IDENTITY_DIR/identity.p12" -k "$KEYCHAIN" -P "$MACOS_EPHEMERAL_P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" > /dev/null
# Only this ephemeral CI user trusts the certificate for applying signatures.
# The app's requirement pins the leaf certificate, not the user's trust store.
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$IDENTITY_DIR/certificate.pem"
FINGERPRINT="$("$OPENSSL" x509 -in "$IDENTITY_DIR/certificate.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"
security find-identity -v -p codesigning "$KEYCHAIN" | grep -qi "$FINGERPRINT"
{
  echo "MACOS_TEST_KEYCHAIN=$KEYCHAIN"
  echo "MACOS_TEST_IDENTITY=$FINGERPRINT"
  echo "MACOS_TEST_CERTIFICATE=$IDENTITY_DIR/certificate.pem"
} >> "$GITHUB_ENV"
rm -f "$IDENTITY_DIR/key.pem" "$IDENTITY_DIR/identity.p12"
unset MACOS_EPHEMERAL_P12_PASSWORD
echo 'One temporary test identity is ready for both versions; private material will never be uploaded.'
