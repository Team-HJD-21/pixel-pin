# Pixel Pin for macOS

This is the native macOS implementation. It mirrors the Windows app's floating picker, live pixel sampling, click-to-pin/resume, HEX/RGB/HSL/HSV/CMYK output, appearance/language settings, recent colors, clipboard copy, and TeamHJD link.

## Build on a Mac

Requires Xcode Command Line Tools and macOS 13 or later:

```sh
bash ./build-app.sh
open "build/Pixel Pin.app"
```

On macOS 14+, choose a display through the system screen picker when the app opens. **Choose a screen** reopens the picker to change the display or restart capture after stopping it in macOS. The app uses ScreenCaptureKit without the deprecated direct capture APIs. On macOS 13, allow Screen Recording in System Settings instead; that version does not provide the system picker.

ScreenCaptureKit produces an explicitly sRGB, SDR BGRA buffer. Both the sampled RGB/HEX value and the 17 × 17 magnifier use those same bytes, avoiding a second display-profile conversion. Compare with Digital Color Meter's **Display in sRGB** mode; native display-profile numbers can differ. HDR luminance outside SDR sRGB is not preserved. Sampling pauses over the app's own windows. Clicking elsewhere pins the color; clicking again resumes. Open Settings from the app menu with `Control+,`.

The build script creates an ad-hoc signed `.app`. This does not remove macOS's first-open security warning; Developer ID signing and notarization require a paid Apple Developer Program membership. Ad-hoc signatures can also cause Screen Recording permission to be requested again after app updates.

## Sparkle updates

Automatic checks and the in-app **Check for Updates** command become active after the one-time update key is configured. On a Mac, from the repository root, resolve Sparkle and create a key pair:

```sh
cd macos
swift build --configuration release --triple arm64-apple-macosx13.0 --build-path .build-arm64
.build-arm64/artifacts/sparkle/Sparkle/bin/generate_keys -x "$HOME/pixelpin-sparkle-private-key.txt"
```

The tool prints the public key and saves the private key to that file. In GitHub, open **Settings → Secrets and variables → Actions**. Add the printed public key as the repository variable `SPARKLE_ED_PUBLIC_KEY`, and the private key file contents as the repository secret `SPARKLE_ED_PRIVATE_KEY`. Keep a secure backup of the private key and never commit it. Stable tagged releases then generate and attach a signed `appcast.xml`; builds without both keys keep update checking disabled.

This Windows checkout cannot validate a macOS runtime, framework loading, or the permission flow.

