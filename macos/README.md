# Pixel Pin for macOS

This is the native macOS implementation. It mirrors the Windows app's floating picker, live pixel sampling, click-to-pin/resume, HEX/RGB/HSL/HSV/CMYK output, appearance/language settings, recent colors, clipboard copy, and TeamHJD link.

## Build on a Mac

Requires Xcode Command Line Tools and macOS 13 or later:

```sh
bash ./build-app.sh
open "build/Pixel Pin.app"
```

On first launch, allow **Screen Recording** when macOS asks. The app captures a 17 × 17 pixel area under the pointer and pauses sampling while the pointer is over its own window. Clicking elsewhere pins the current color; clicking again resumes live sampling.

The build script creates an ad-hoc signed `.app`. This lets macOS identify the exact same build between launches, but an ad-hoc signature is tied to that binary; updating the app can require Screen Recording permission again. Public distribution should use TeamHJD's stable Apple Developer ID signature and notarization. This Windows checkout cannot validate a macOS runtime or its permission flow.

