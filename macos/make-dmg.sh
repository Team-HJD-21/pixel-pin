#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DMG="${1:?Pass the destination dmg path}"
APP="$ROOT/build/Pixel Pin.app"
test -d "$APP"
STAGING="$(mktemp -d "$ROOT/build/dmg.XXXXXX")"
ditto "$APP" "$STAGING/Pixel Pin.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p "$STAGING/.background"
swift "$ROOT/installer/background.swift" "$STAGING/.background/installer.tiff" "$ROOT/build/installer-preview.png"
WRITABLE="$STAGING.dmg"
hdiutil create -ov -volname 'Pixel Pin' -fs HFS+ -srcfolder "$STAGING" -format UDRW "$WRITABLE"
MOUNT="$(mktemp -d "$ROOT/build/mount.XXXXXX")"
hdiutil attach "$WRITABLE" -readwrite -nobrowse -mountpoint "$MOUNT" > /dev/null
trap 'hdiutil detach "$MOUNT" > /dev/null 2>&1 || true' EXIT
python3 "$ROOT/installer/layout.py" "$MOUNT"
hdiutil detach "$MOUNT"
trap - EXIT
hdiutil convert "$WRITABLE" -ov -format UDZO -o "$DMG"
hdiutil verify "$DMG"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT" > /dev/null
trap 'hdiutil detach "$MOUNT" > /dev/null 2>&1 || true' EXIT
test -d "$MOUNT/Pixel Pin.app"
test "$(readlink "$MOUNT/Applications")" = /Applications
codesign --verify --deep --strict "$MOUNT/Pixel Pin.app"
python3 "$ROOT/installer/layout.py" "$MOUNT" --verify-only
hdiutil detach "$MOUNT"
trap - EXIT
