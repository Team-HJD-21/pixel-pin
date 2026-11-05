<div align="center">

[한국어](../README.md) · **English** · [简体中文](README.zh-CN.md)

<br /><img src="../assets/app-icon.png" width="96" height="96" alt="Pixel Pin" />

# Pixel Pin

[Terms of Use](https://pixelpin.teamhjd.com/en/terms/) · [Privacy Policy](https://pixelpin.teamhjd.com/en/privacy/) · [Support & payments](https://pixelpin.teamhjd.com/en/support/)

Updated builds add **Clear recent colors** and **Restore default preferences** to Settings. Clearing colors removes current and legacy history; restoring preferences resets appearance, language, format, and window mode. Neither clears the Windows clipboard. With v1.1.0, close the app and manually remove local files in `%LOCALAPPDATA%\PixelPin`, and any legacy `%LOCALAPPDATA%\DigitalColorMeter\history.json`, if you want to erase them.

The app is free. Optional Lemon Squeezy purchases are under consideration and are not enabled. Product, seller, privacy, and refund details must be confirmed before payment is offered.

**Pick a color. Pin the pixel. Copy it your way.**

A small, clean Windows color picker by [TeamHJD](https://teamhjd.com/).

[Website](https://pixelpin.teamhjd.com/) · [Download](https://github.com/Team-HJD-21/pixel-pin/releases/latest) · [Release notes](https://pixelpin.teamhjd.com/changelog/) · [Issues](https://github.com/Team-HJD-21/pixel-pin/issues)

<br /><img src="https://github.com/user-attachments/assets/17312d7b-05b8-444d-929e-08334b704244" width="360" alt="Pixel Pin interface with a sample color" />

<sub>Interface example with sample color #547CF0</sub>

</div>

## A few useful things, done well

| Feature | What it does |
| :--- | :--- |
| Live color picking | Reads the physical screen pixel under your pointer. |
| Click to pin / resume | Click once to hold a color. Click again to keep picking. |
| Pixel magnifier | Shows a 17 × 17 pixel region and highlights the sampled pixel. |
| Five color formats | HEX, RGB, HSL, HSV, and reference CMYK. |
| Appearance | Light, dark, or follow device settings, including live system theme changes. |
| Three languages | 한국어, English, and 简体中文, including translated buttons and help text. |
| Everyday conveniences | Always-on-top window, eight recent colors, and readable copy-button text. |
| Mini mode | A small window with the color, formatted value, copy and pin/resume controls. Remembers your last mode. |

No account or installer is required. The app does not send screen images or color history to a server. The TeamHJD link opens in your default browser only when clicked.

## Download and run

1. Get the **Windows x64 ZIP** from the [latest release](https://github.com/Team-HJD-21/pixel-pin/releases/latest).
2. Extract it to a folder.
3. Run **`PixelPin.exe`**.

Targets **Windows 10 / 11, x64**. Official releases include the .NET runtime; no separate runtime installation is required.

## Pick → pin → copy

Move the pointer outside the app to find a color. Left-click the screen to pin it, then press the copy button. The value is copied in your selected format. Click the screen again or use **Resume picking** to continue.

| Shortcut | Action |
| :--- | :--- |
| `Ctrl + Shift + C` | Copy the current color |
| `Ctrl + Shift + Space` | Pin / resume picking |
| `Ctrl + Shift + M` | Switch between standard and mini mode while the app is focused |

Clicks inside the app or settings window do not toggle picking. Recent colors are copied in the currently selected format. If another app owns a shortcut, use the on-screen buttons.

> Screen clicks also reach the application underneath. To pin a color without activating a button or link, use the keyboard shortcut.

## Make it yours

Open the **settings icon in the top-right corner**. Changes apply immediately and persist between sessions.

- **Appearance:** Use device settings / Light / Dark
- **Language:** 한국어 / English / 简体中文
- **Color format:** HEX / RGB / HSL / HSV / CMYK
- **Window mode:** Standard / Mini. You can also use the window-mode button in the title bar. On macOS, press `Command + Shift + M`; opening Settings temporarily expands the mini window and closing it restores the compact view.

| Format | Example | Notes |
| :--- | :--- | :--- |
| HEX | `#FF8000` | Hexadecimal 8-bit sRGB |
| RGB | `rgb(255, 128, 0)` | RGB channel values |
| HSL | `hsl(30.1, 100%, 50%)` | Hue, saturation, lightness |
| HSV | `hsv(30.1, 100%, 100%)` | Hue, saturation, value; not standard CSS syntax |
| CMYK | `cmyk(0%, 49.8%, 100%, 0%)` | Reference conversion from RGB, without an ICC print profile; not standard CSS syntax |

## HDR and color limits

Where supported, DirectX desktop duplication preserves the source format. FP16 scRGB pixels are normalized using the Windows SDR white level, then converted to sRGB. Values above the SDR range are scaled while preserving channel ratios. The app labels this path **`HDR/scRGB → sRGB`**.

**An SDR HEX/RGB value cannot reproduce the full brightness, gamut, or perceived appearance of an HDR display.** Pixel Pin does not analyze print profiles or the original image's color profile. Matching the visible HDR display still requires checking the specific display, driver, and color pipeline.

When DirectX capture is unavailable, the app explicitly labels its GDI compatibility capture path. HDR values may differ on that path. Protected content and secure screens cannot be sampled. The implementation handles multiple monitors, negative coordinates, and display rotation.

Settings and history are stored in `%LOCALAPPDATA%\PixelPin\settings.json` and `history.json`. Color history from the previous Digital Color Meter version is preserved.

## Build

Requires Windows and **.NET SDK 10**. Uses WPF, Windows APIs, and [Vortice.Windows](https://github.com/amerkoleci/Vortice.Windows) DirectX bindings.

```powershell
git clone https://github.com/Team-HJD-21/pixel-pin.git
cd pixel-pin
dotnet run --project PixelPin.csproj
```

Self-contained single-file release:

```powershell
dotnet publish PixelPin.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true -p:DebugType=None -o artifacts/win-x64
```

The website lives in `site/` and deploys through GitHub Pages. Publishing or editing a release rebuilds the download links and release notes from public GitHub releases. Visitors do not make GitHub API requests.

<div align="center"><br /><a href="https://teamhjd.com/"><strong>Made by TeamHJD</strong></a><br /><sub>© 2026 TeamHJD. All rights reserved.</sub></div>
