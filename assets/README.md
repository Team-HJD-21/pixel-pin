# Asset provenance

- `app-icon.svg`: project-owned vector source for the Pixel Pin icon. `generate-icon.ps1` exports the project's PNG and ICO variants. No supplied stock preview, watermark, or checkerboard image is shipped as an icon.
- `preview-*.png` and `settings-*.png`: illustrations rendered from Pixel Pin's own WPF UI, using synthetic example colors. These are app layout examples, not captures of a user's desktop. Older `preview.png`, `settings.png`, and `*-dark-zh.png` files are retained compatibility examples of the same UI.
- Pause, play, settings, and color-picker symbols are inline project vector geometry in XAML or HTML.
- Fonts are system font fallbacks; no font file is bundled or downloaded by the website. Naming a font in a fallback list does not redistribute it.
- Third-party software notices are in the root `NOTICE.md` and `third-party/`. Keep them in release packages along with the bundled runtime's license files.

When adding an external asset, record its source, author, license, and any required attribution here before shipping it. This file does not grant redistribution rights beyond the project's terms or the relevant third-party license.
