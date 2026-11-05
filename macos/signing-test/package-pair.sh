#!/bin/bash
set -euo pipefail
trap 'echo "::error file=macos/signing-test/package-pair.sh,line=$LINENO::Signing test packaging failed" >&2' ERR
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$RUNNER_TEMP/pixelpin-test-artifacts"
mkdir -p "$OUT" "$ROOT/build"
BASELINE_TAG="macos-signing-test-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT-baseline"
UPDATE_TAG="macos-signing-test-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT-update"
for version in 1.2.3 1.2.4; do
  tag="$BASELINE_TAG"
  if [[ "$version" == 1.2.4 ]]; then tag="$UPDATE_TAG"; fi
  ditto "$MACOS_TEST_WORK/$version/Pixel Pin.app" "$ROOT/build/Pixel Pin.app"
  archive="Pixel-Pin-$tag-macos-universal.zip"
  dmg="Pixel-Pin-$tag-macos-universal.dmg"
  ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/Pixel Pin.app" "$OUT/$archive"
  unzip -tqq "$OUT/$archive"
  bash "$ROOT/make-dmg.sh" "$OUT/$dmg"
  (cd "$OUT" && shasum -a 256 "$archive" > "$archive.sha256" && shasum -a 256 "$dmg" > "$dmg.sha256")
done
printf '%s\n' "$SPARKLE_ED_PRIVATE_KEY" | bash "$ROOT/make-appcast.sh" "$OUT/Pixel-Pin-$UPDATE_TAG-macos-universal.zip" "$UPDATE_TAG"
cp "$ROOT/update-feed/appcast.xml" "$OUT/appcast.xml"
cp "$MACOS_TEST_WORK/signing-verification.txt" "$OUT/signing-verification.txt"
cp "$MACOS_TEST_CERTIFICATE" "$OUT/certificate.pem"
{
  echo "baseline_tag=$BASELINE_TAG"
  echo "update_tag=$UPDATE_TAG"
  echo "artifact_dir=$OUT"
} >> "$GITHUB_OUTPUT"
