# Architecture

## What runs where

An Omarchy shell plugin of kinds `overlay` and `bar-widget` (`manifest.json`, schema version 1, validated by
`omarchy plugin validate`), checked on Omarchy 4.0 with Quickshell 0.3.1. It runs inside the shared `omarchy-shell`
process (`quickshell -n -p /usr/share/omarchy/shell`), not as a process of its own. The shell calls `open(payload)`
and `close()` on `app/Overlay.qml`'s root; `summon`, `hide` and `toggle` are built from those. `open` understands
`{"allApps":true}`, `{"options":true}`, `{"reload":true}`, `{"tab":"colors"}`, `{"profile":"work"}` and, from the bar button,
`{"anchor":{"x","y","screen"}}` (where the button is on its screen: `BarWidget.qml` turns the bar window's coordinates
into screen ones with `Fx.screenPoint()`, since a bottom or right bar's window is offset). The bar button's left click
toggles, right click opens a small popup (Settings = `{"options":true}`, Reload = `{"reload":true}`, About = `xdg-open` of the repository,
and the version read from `manifest.json`), middle click opens "All apps".

## Files

`app/Overlay.qml` is the only place with state and logic. Every other `.qml` is a view that receives it as `shell`.
The plugin's own code is all under `app/`, and `manifest.json` points its entry points there (`app/Overlay.qml`,
`app/BarWidget.qml`). Quickshell resolves types from the same directory or from one imported with `import "folder"`,
so each folder is a group of types and a file imports the folders it draws from.

```
manifest.json
app/
  Overlay.qml, BarWidget.qml     entry points
  launcher/                      LauncherContent, Node, AppCell, SearchResults, Picker, ProfileButton, FxLayer
  menus/                         OptionsMenu, TileMenu, ColorField, ProfilePicker, ConfigTransfer, Welcome
    controls/                    Menu*, Slider*, FocusRing (the menus' building blocks)
    previews/                    Tiles, Theme, Window, Effect, Buttons and Preset previews
  lib/                           layout, keys, colors, toml, config, fx, presets, menuIcons (.js)
  presets/                       omarchy, top, dock, focus, clean (.toml)
  shaders/                       fx.frag + fx.frag.qsb
  assets/icons/themes/           strip button styles
```

| Group | Files |
|---|---|
| State and windows | `app/Overlay.qml` (settings, tile tree, filter and selection, usage, profiles, presets and the welcome screen, the layer-shell windows), `app/BarWidget.qml` |
| Launcher content | `app/launcher/`: `LauncherContent.qml`, `Node.qml` (a tile or a split, recursive), `AppCell.qml`, `SearchResults.qml`, `Picker.qml`, `ProfileButton.qml` |
| ⚙ menu | `app/menus/`: `OptionsMenu.qml`, `ColorField.qml`, `ProfilePicker.qml`, `ConfigTransfer.qml`, `Welcome.qml` (the presets to choose from on the first start); `app/menus/controls/`: `MenuTabBar`, `MenuSection`, `MenuToggle`, `MenuChoice`, `MenuButton`, `MenuTip`, `FocusRing`, `SliderRow`, `SliderTrack`, `SliderValue`, `MenuIcon` |
| Opening effects | `app/launcher/FxLayer.qml` (the layer that draws one), `app/shaders/fx.frag` + `fx.frag.qsb` (the shader), `app/lib/fx.js` (curves and geometry) |
| Previews | `app/menus/previews/`: `TilesPreview`, `ThemePreview`, `WindowPreview`, `EffectPreview`, `ButtonsPreview`, `PresetPreview` (a preset on the welcome screen) |
| ⋯ tile menu | `app/menus/TileMenu.qml`, and from `controls/` `MenuPage`, `MenuGroup`, `MenuCheck` |
| Pure logic (`.pragma library`, `app/lib/`) | `layout.js` (tree edits, tile minimum size), `keys.js` (key combinations), `colors.js` (colour fields, surfaces and contrast), `toml.js` (TOML reader/writer), `config.js` (settings ↔ file sections), `fx.js` (effect curves and where an effect starts from), `presets.js` (the presets and where the launcher sits in their pictures), `menuIcons.js` (the tab icons' paths) |

The scripts never read `shell`; they take everything as arguments and are tested with Node.

## Two layer-shell windows

`launcherWin` is always a full-screen surface, mapped while the launcher is open or animating out. Inside it,
`card` (centered mode) and `dockedArea` (a panel on an edge, or full screen) are plain Items, and `fx` (`FxLayer`) is
the layer that draws an opening effect over whichever is showing. `menuWin` hosts the
⚙ and ⋯ menus and takes the keyboard while one is open. Hyprland stacks same-layer surfaces in the order they
were mapped, so `open()` sets `opened` before `optionsOpen`: the menu then lands on top.

Traps that cost time: `dockedArea` is placed with `x`/`y`, never anchors (switching mode briefly anchored two
opposite edges and killed its height binding); only the `Loader` of the mode in use may have `focus: true` (two
of them compete and the hidden one keeps the keyboard, so Esc and typing reach nothing).

## Settings and saving

Settings live in `saved`, a `JsonAdapter` inside a path-less `FileView`, only so a change fires
`adapterUpdated`. Root properties are aliases of it (`iconSize` is `saved.icon`). A change schedules
`saveNow()`, which writes `config.toml` (or the profile in use) through `toml.js` and `config.js`; a change to
the tile tree goes through `commit()`, which also keeps the undo history. See [configuration](configuration.md)
for the file, profiles and the usage history.

## Colours

Two modes, Dark and Light (or Auto, from Omarchy's own setting), each with its own set of colour fields. A field
resolves per part, tile then global then system default. The text colour is never fixed: it is measured on the
surface it sits on (`appSurface`, `menuSurface`, a tile's own), so any background stays readable. With
"Follow the Omarchy theme" the swatches and system backgrounds come from
`~/.local/state/omarchy/current/theme/colors.toml`, read at start and on each open.

## Menus

Nine tabs (Tiles, Colors, Window, Effects, Search, Buttons, Keys, Menu, Profiles), all the same height (the tallest page's, kept under about 500 px so the menu fits a 768 px screen at
100 %). Rows that do not apply are dimmed, never hidden. Sliders have ↺, typed values and keyboard use; the
bottom row has "Reset this tab" and "Done". Text and chrome in the menus use the `m…` colours of `Overlay.qml`
(`mFg`, `mDim`, `mBorder`, ...), never the launcher's `fg`/`dim`.

## Opening effects

What the effects are and how a person uses them is in [effects](effects.md). In the code, `window.effect` is `classic`
(the default: `mover` slides a docked panel in, `mover.opacity` fades full screen, a centered window has nothing to do)
or one of the names in `Fx.NAMES` (`fx.js`). Those are one shader, `app/shaders/fx.frag` (compiled to `fx.frag.qsb` by
`tools/build-shaders.sh`, committed next to it; `tests/verify.sh` checks it is current), run by `FxLayer.qml` over a frozen
picture of the launcher (`ShaderEffectSource`, not live: taken by `snap()` when it opens or closes). The layer fills the
whole window so an effect can travel or overshoot past the launcher's own bounds; while `slide < 1` the real launcher is
hidden (`hideSource`) and the picture is drawn through the shader, at 1 the live launcher shows. Every effect works
backwards: for each pixel it says which point of the picture goes there. The terminal ones (`Fx.TERMINAL`) treat the
launcher as a grid of 12 × 24 px cells (at 1080 p) with made-up dot glyphs.

- `slide` (0..1) is linear under an effect; the curve of each one (springs that pass 1) is `Fx.ease()` in `fx.js`.
  `onOpenedChanged` sets the length and curve of the animation before it writes `slide`: a binding on `opened` inside
  the animation can be read too late and use the closing length to open.
- Where an effect starts from is `Fx.geometry()`: the bar button when it opened the launcher (`anchorPos`, in screen
  coordinates: `BarWidget.qml` moves the bar window's coordinates with `Fx.screenPoint()`), otherwise the docked edge
  or the centre; genie without a button is drawn into the bottom of the screen like a dock.
- `EffectPreview.qml` (⚙ > Effects) plays the chosen effect on a loop through the same `FxLayer`.
- Adding an effect: a function in `fx.frag` and a `mode` number, a line in `Fx.NAMES` / `MODES` / `curve()` (and
  `TERMINAL` or `BASIC`), a description in `EffectPreview.qml` and an option in the Effects tab, `effects.body` loops the
  names by itself; run `tools/build-shaders.sh`. Keep the Effects tab under the height of the tallest tab (768 px screens).
- Classic and the shader effects never run together: `fxOn` is `effect !== "classic"`, and `mover` stays put while an
  effect plays.
