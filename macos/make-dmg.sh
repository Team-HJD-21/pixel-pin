#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DMG="${1:?Pass the destination dmg path}"
APP="$ROOT/build/Pixel Pin.app"
test -d "$APP"
STAGING="$(mktemp -d "$ROOT/build/dmg.XXXXXX")"
ditto "$APP" "$STAGING/Pixel Pin.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -ov -volname 'Pixel Pin' -fs HFS+ -srcfolder "$STAGING" -format UDZO "$DMG"
hdiutil verify "$DMG"
MOUNT="$(mktemp -d "$ROOT/build/mount.XXXXXX")"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT" > /dev/null
trap 'hdiutil detach "$MOUNT" > /dev/null 2>&1 || true' EXIT
test -d "$MOUNT/Pixel Pin.app"
test "$(readlink "$MOUNT/Applications")" = /Applications
codesign --verify --deep --strict "$MOUNT/Pixel Pin.app"
hdiutil detach "$MOUNT"
trap - EXIT
