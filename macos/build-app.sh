#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/build}"
APP="$OUT/Pixel Pin.app"

swift build --package-path "$ROOT" --configuration release --triple arm64-apple-macosx13.0 --build-path "$ROOT/.build-arm64"
swift build --package-path "$ROOT" --configuration release --triple x86_64-apple-macosx13.0 --build-path "$ROOT/.build-x86_64"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Resources/ko.lproj" "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/zh-Hans.lproj"
lipo -create "$ROOT/.build-arm64/release/PixelPin" "$ROOT/.build-x86_64/release/PixelPin" -output "$APP/Contents/MacOS/PixelPin"
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
cat > "$APP/Contents/Info.plist" <<'PLIST'
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
<key>CFBundleVersion</key><string>1.2.0</string>
<key>CFBundleShortVersionString</key><string>1.2.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Pixel Pin reads the pixel beneath your pointer to show its color and magnified view.</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict></plist>
PLIST
echo "Created $APP"
echo "For public distribution, sign with Developer ID and notarize this app before packaging it."
