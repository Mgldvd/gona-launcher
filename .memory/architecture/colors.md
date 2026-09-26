# Colours

The overview is in [docs/architecture.md](../../docs/architecture.md#colours); the `[colors]` keys in
[docs/configuration.md](../../docs/configuration.md#colours).

- `theme`: `"dark"`, `"light"` or `"auto"` (the Omarchy theme's mode); `setTheme()`, Ctrl+T. Each look has its own 8
  palette colours (`paletteDark` vivid, `paletteLight` deeper; `palette` is the one in use) and its own field set:
  `colorsDark` (stored under the old `colors` key so pre-two-look data applies to Dark) and `colorsLight`.
  **`root.colors` is the set of the look in use and the only one read elsewhere; `setColor()` writes to it.**
- Fields `accent`, `border`, `bg` (tiles), `appBg` (gaps), `powerBg`, `menuBg`, each `{v, a}`: `v` is `"system"`,
  `"none"`, palette index 0–7 or `"#rrggbb"`; `a` is opacity 0–100; either may be missing. A tile overrides as
  `cBorder`/`cBg` in its leaf (a palette index adapts to the look, a hex is the same in both). Resolution per part:
  tile → global → system default (`pick()`, `paint()`, `systemHex()`); ↺ deletes the field.
- A palette colour as a tile `bg` is a soft tint (`tintOf()`); `swatchFor()` is what a swatch shows so the picker
  previews the result. `ThemePreview.qml` draws from the same `paint()`/`pick()` calls.
- **Text follows the surface**: launcher `fg/dim/border/hover` are measured on `appSurface` (`appBg` over `deskRgb`),
  menus use `mFg/mDim/mBorder/mHover/mField/mPopup/mDanger` measured on `menuSurface`, tiles `tileIsLight()`/
  `inkColor()` (`colors.js`: `over`, `luminance`, `isLight`). **Menu files use only the `m…` names, never
  `shell.fg`/`dim`/…, and no hard-coded hex greys.** `ColorField.qml` is the only UI for the fields.
- Omarchy theme: `refreshOmarchy()` reads `~/.local/state/omarchy/current/theme/colors.toml` at start and every `open()`
  into `omarchyColors`. With `followTheme` and the theme's mode equal to the look (`following`), the swatches are the
  theme's accent, red, orange, yellow, green, cyan, blue, magenta (`paletteNames`), and `"system"` backgrounds are its
  `background`/`lighter_background`; otherwise the fixed palettes. `"system"` menu background is `#313244` Dark /
  `#ffffff` Light.
