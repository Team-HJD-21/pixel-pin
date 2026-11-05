#!/bin/bash
set -euo pipefail
trap 'echo "::error file=macos/build-app.sh,line=$LINENO::macOS build failed during ${PHASE:-setup}" >&2' ERR

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/build}"
APP="$OUT/Pixel Pin.app"
PHASE="${2:-all}"
APP_VERSION="${MACOS_APP_VERSION:-1.2.1}"
APP_VERSION="${APP_VERSION#v}"
APP_VERSION="${APP_VERSION%%-*}"
APP_BUILD_NUMBER="${MACOS_BUILD_NUMBER:-$APP_VERSION}"
SPARKLE_PUBLIC_KEY="${SPARKLE_ED_PUBLIC_KEY:-}"
UPDATE_FEED="${MACOS_UPDATE_FEED_URL:-https://github.com/Team-HJD-21/pixel-pin/releases/download/macos-updates/appcast.xml}"
[[ "$APP_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || { echo 'Invalid app version' >&2; exit 1; }
[[ "$APP_BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || { echo 'Invalid build number' >&2; exit 1; }
case "$PHASE" in all|arm64|x86_64|package) ;; *) echo 'Unknown build phase' >&2; exit 1 ;; esac

if [[ "$PHASE" == all || "$PHASE" == arm64 ]]; then
swift build --package-path "$ROOT" --configuration release --triple arm64-apple-macosx13.0 --build-path "$ROOT/.build-arm64" -Xlinker -rpath -Xlinker '@executable_path/../Frameworks'
fi
if [[ "$PHASE" == all || "$PHASE" == x86_64 ]]; then
swift build --package-path "$ROOT" --configuration release --triple x86_64-apple-macosx13.0 --build-path "$ROOT/.build-x86_64" -Xlinker -rpath -Xlinker '@executable_path/../Frameworks'
fi
if [[ "$PHASE" != all && "$PHASE" != package ]]; then exit 0; fi
test -x "$ROOT/.build-arm64/release/PixelPin"
test -x "$ROOT/.build-x86_64/release/PixelPin"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
mkdir -p "$APP/Contents/Resources/ko.lproj" "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/zh-Hans.lproj"
lipo -create "$ROOT/.build-arm64/release/PixelPin" "$ROOT/.build-x86_64/release/PixelPin" -output "$APP/Contents/MacOS/PixelPin"
SPARKLE_FRAMEWORK="$(find "$ROOT/.build-arm64/artifacts" -type d -name Sparkle.framework -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found in SwiftPM artifacts." >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$ROOT/../assets/app-icon.png" "$APP/Contents/Resources/AppIcon.png"
cp "$ROOT/InfoPlist/ko.lproj/InfoPlist.strings" "$APP/Contents/Resources/ko.lproj/InfoPlist.strings"
cp "$ROOT/InfoPlist/en.lproj/InfoPlist.strings" "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
cp "$ROOT/InfoPlist/zh-Hans.lproj/InfoPlist.strings" "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"
mkdir -p "$OUT/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT/../assets/app-icon.png" --out "$OUT/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ROOT/../assets/app-icon.png" --out "$OUT/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$OUT/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PixelPin</string>
<key>CFBundleIdentifier</key><string>com.teamhjd.pixelpin</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>Pixel Pin</string>
<key>CFBundleDisplayName</key><string>Pixel Pin</string>
<key>CFBundleLocalizations</key><array><string>ko</string><string>en</string><string>zh-Hans</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$APP_BUILD_NUMBER</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Pixel Pin reads the pixel beneath your pointer to show its color and magnified view.</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>SUFeedURL</key><string>$UPDATE_FEED</string>
<key>SUEnableAutomaticChecks</key><false/>
</dict></plist>
PLIST
if [[ -n "$SPARKLE_PUBLIC_KEY" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :SUEnableAutomaticChecks true" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUVerifyUpdateBeforeExtraction bool true" "$APP/Contents/Info.plist"
fi
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
lipo "$APP/Contents/MacOS/PixelPin" -verify_arch arm64 x86_64
lipo "$APP/Contents/Frameworks/Sparkle.framework/Sparkle" -verify_arch arm64 x86_64
bash "$ROOT/ci/sign-app.sh" "$APP"
echo "Created $APP"
echo "Developer ID signing and notarization are separate from fixed self-signing."
