# Pixel Pin for macOS

This is the native macOS implementation. It mirrors the Windows app's floating picker, live pixel sampling, click-to-pin/resume, HEX/RGB/HSL/HSV/CMYK output, appearance/language settings, recent colors, clipboard copy, and TeamHJD link.

Use the title-bar window-mode button, **Mini mode** in Settings, or `Command+Shift+M` to switch to a small floating picker. It keeps the same sampled color, selected format, clipboard action and pin/resume state, and remembers the last mode. Native macOS window controls remain available. Settings temporarily expands the window and returns to mini mode when dismissed. Window layout checks cover returning to standard size, short displays and displays with negative desktop coordinates.

## Build on a Mac

Requires Xcode Command Line Tools and macOS 13 or later:

```sh
bash ./build-app.sh
open "build/Pixel Pin.app"
```

For a fresh installation, download the DMG, open it, and drag **Pixel Pin.app** onto **Applications**. Eject the image and launch the installed app from Applications. Updates are disabled when running the app from Downloads, a mounted DMG, or another temporary location; the app shows installation guidance there. ZIP archives remain available for Sparkle's signed updates.

The DMG has a fixed Finder icon layout, a Retina installer background and installation instructions in Korean, English and Simplified Chinese. These are generated without Finder automation. Creating the DMG locally also requires `python3 -m pip install --require-hashes -r installer/requirements.txt`; CI installs these checksum-pinned dependencies automatically. The final mounted image is checked for icon positions, the background alias and app signature.

By default, authorize Screen Recording in System Settings and the app automatically samples the entire display under the pointer, switching displays as the pointer moves. macOS may independently request renewed direct-capture access; the app cannot suppress these OS prompts. Disable **Start screen sampling automatically** in Settings to use the system picker on macOS 14+, or use **Choose a screen** for the current session. The app continues to use ScreenCaptureKit and does not capture audio.

ScreenCaptureKit produces an explicitly sRGB, SDR BGRA buffer. Both the sampled RGB/HEX value and the 17 × 17 magnifier use those same bytes, avoiding a second display-profile conversion. Compare with Digital Color Meter's **Display in sRGB** mode; native display-profile numbers can differ. HDR luminance outside SDR sRGB is not preserved. Sampling pauses over the app's own windows. Clicking elsewhere pins the color; clicking again resumes. Open the centered Settings popup with `Command+,`; click outside it or press Escape to dismiss it.

Local and PR builds use an ad-hoc signature. Official releases from v1.2.5 use a persistent self-signing certificate and an explicit designated requirement bound to its leaf fingerprint. Permission retention across two versions was confirmed by the maintainer on a Mac. Transitioning from an old ad-hoc build or the isolated test identity may require one permission re-registration. Self-signing does not remove macOS's first-open warning and is not Developer ID signing or notarization.

The red close button minimizes the app to the Dock by default. Change **Close button** to **Quit Pixel Pin** in Settings to quit instead. This preference persists between launches; `Command+Q` and the Quit menu command always quit the app.

If Screen Recording is enabled but capture is denied, use **Permission settings** in the app, check the installed Pixel Pin entry, and return to the app. It attempts one reconnection after returning from settings. **Try again** explicitly requests access again; automatic startup never uses a saved “permission requested” flag to block capture. The actual ScreenCaptureKit result determines whether capture is authorized, and failed attempts include expandable diagnostic details. Some macOS permission changes require quitting and reopening the app, as in Apple's ScreenCaptureKit sample. Ad-hoc app updates can invalidate an earlier permission entry; this is not a permanent approval guarantee.

## Sparkle updates

Automatic checks and the in-app **Check for Updates** command become active after the one-time update key is configured. On a Mac, from the repository root, resolve Sparkle and create a key pair:

```sh
cd macos
swift build --configuration release --triple arm64-apple-macosx13.0 --build-path .build-arm64
.build-arm64/artifacts/sparkle/Sparkle/bin/generate_keys
.build-arm64/artifacts/sparkle/Sparkle/bin/generate_keys -x "$HOME/pixelpin-sparkle-private-key.txt"
```

The first key command creates a key pair in the login Keychain and prints the public key. The second exports that existing private key to the file; `-x` does not create a missing key. In GitHub, open **Settings → Secrets and variables → Actions**. Add the printed public key as the repository variable `SPARKLE_ED_PUBLIC_KEY`, and the private key file contents as the repository secret `SPARKLE_ED_PRIVATE_KEY`. Keep a secure backup of the private key and never commit it. Tagged releases require both keys and validate signed archives before publishing.

Beta apps use the permanent `macos-beta-updates` release asset feed; stable apps use `macos-updates`. Each versioned release also includes its appcast and archive SHA-256. macOS releases do not replace the repository's Windows latest-release link. The update key must be included when the app is built, so older preview builds without it need one manual installation of a signed-update-enabled build. Sparkle signing is separate from Apple Developer ID signing and notarization.

Stable releases are also published to the beta update feed so existing beta installations can move to the stable app and its stable feed. The website selects stable Windows and macOS downloads independently and prefers the Mac DMG.

## CI checks

Ubuntu first validates the workflow using checksum-verified actionlint 1.7.12 and checks Bash syntax. macOS 15 Intel uses Xcode 16.4 explicitly, runs the raster tests, builds Apple silicon and Intel in separate steps, then validates the complete plist, both executable architectures, the embedded framework, the app signature, and the ZIP archive. Release jobs generate and validate the signed appcast before uploading any release files. Outdated branch jobs are cancelled; tagged release jobs remain independent.

### Persistent signing identity

The repository secrets `MACOS_SIGNING_P12_BASE64` (base64-encoded encrypted PKCS#12) and `MACOS_SIGNING_P12_PASSWORD` contain the fixed app-signing identity. Its public certificate is pinned in `ci/signing-certificate.pem`. The importer compares the certificate bytes before importing, checks its remaining validity and enables noninteractive code-signing access only on the disposable CI runner. Signing preserves the nested Sparkle signatures and uses `identifier "com.teamhjd.pixelpin" and certificate leaf = H"<fingerprint>"`. Release jobs refuse an ad-hoc fallback. Temporary keychains and CI trust entries are cleaned even after failures.

Do not regenerate or replace this certificate between releases. Keep the encrypted PKCS#12 and its password backup securely outside the checkout; losing the identity or rotating it may require users to register permission again. Private keys are excluded from source, artifacts and compilation snapshots. The Sparkle Ed25519 key remains a separate update-authentication key. This fixed certificate does not make the app notarized or remove Gatekeeper warnings.

Successful push builds retain a checksummed snapshot of both compiled executables and the Sparkle tools for 14 days. A later tag or rerun on the **exact same commit** reuses these inputs after checking the workflow, repository, successful run, compiler fingerprint, source SHA and architectures. A tag waits up to eight minutes for an earlier same-commit build rather than compiling concurrently. Missing, expired or incompatible inputs fall back to the full test/build path. Release version, build number, update feed and public key are always applied afresh when assembling the app; bundle, DMG and update-signature checks still run. Private signing keys are never included in the snapshot.

PR merge results still get their own checks, and PR builds cannot supply reusable release inputs. Documentation-only edits do not trigger macOS compilation. To use the fast release path, push the final commit, then tag that exact commit; avoid making a separate version-only source commit between testing and tagging.

`build-app.sh OUTPUT arm64`, `build-app.sh OUTPUT x86_64`, and `build-app.sh OUTPUT package` expose those same stages locally. Running it without a stage still builds and packages everything.

This Windows checkout cannot validate a macOS runtime, framework loading, or the permission flow.

