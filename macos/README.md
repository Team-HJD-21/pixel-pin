# Pixel Pin for macOS

This is the native macOS implementation. It mirrors the Windows app's floating picker, live pixel sampling, click-to-pin/resume, HEX/RGB/HSL/HSV/CMYK output, appearance/language settings, recent colors, clipboard copy, and TeamHJD link.

## Build on a Mac

Requires Xcode Command Line Tools and macOS 13 or later:

```sh
bash ./build-app.sh
open "build/Pixel Pin.app"
```

On first launch, allow **Screen Recording** when macOS asks. The app captures a 17 × 17 pixel area under the pointer and pauses sampling while the pointer is over its own window. Clicking elsewhere pins the current color; clicking again resumes live sampling.

The script creates an unsigned local `.app` for development. Before publishing a download, build and verify on macOS, sign with TeamHJD's Apple Developer ID, notarize it, and package the signed app as a DMG or ZIP. This Windows checkout cannot validate a macOS build or its permission flow.
