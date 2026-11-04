# Pixel Pin for macOS

This is the native macOS implementation. It mirrors the Windows app's floating picker, live pixel sampling, click-to-pin/resume, HEX/RGB/HSL/HSV/CMYK output, appearance/language settings, recent colors, clipboard copy, and TeamHJD link.

## Build on a Mac

Requires Xcode Command Line Tools and macOS 13 or later:

```sh
bash ./build-app.sh
open "build/Pixel Pin.app"
```

On first launch, allow **Screen Recording** when macOS asks. If access was denied earlier, use the permission button in the app to open System Settings, enable Pixel Pin, then reopen the app. The app captures the pixel under the pointer and a 17 × 17 magnified area, using sRGB output; it pauses sampling while the pointer is over its own window. Clicking elsewhere pins the current color; clicking again resumes live sampling. Open Settings from the app menu with `Control+,`.

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

