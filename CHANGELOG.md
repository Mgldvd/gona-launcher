# Changelog

What changed in each version of Gona Launcher, newest first. **Every commit that changes `app/` or `manifest.json` adds its
line under "Unreleased" in the same commit** (a hook checks it: see [CONTRIBUTING.md](CONTRIBUTING.md)); a release turns that
section into a dated one and raises `version` in `manifest.json`.

To get a new version: `omarchy plugin update gona.launcher` (it shows you the changes first), then `omarchy restart shell` if the
launcher looks unchanged.

## Unreleased

- Security: turning Super alone on or off no longer passes the whole of `~/.config/hypr/bindings.lua` (which can hold tokens)
  as a command argument, where other processes could read it; the launcher now writes its files itself, and the same goes for
  saving and renaming profiles.

## 1.0.0 - 2026-09-26

The first public version.

**Tiles.** Apps live in tiles you split right or down, name, colour and drag between. Icons shrink so none is ever cut off,
however many apps a tile holds. A tile's ＋ and ⋯ buttons show after the pointer has rested on it for a few seconds (or never:
⚙ > Tiles > Tile buttons), and a right-click opens its menu at once.

**Ready-made profiles.** The first start offers Omarchy, Top, Dock, Focus and Clean; later they are added as profiles next to
yours, never replacing anything. A profile is a saved set of tiles and settings: switch with Ctrl+P, buttons in the strip
(⚙ > Buttons) or a keybinding; they are listed in the order they were made.

**Opening.** A centred window, a panel on any of the four edges, or full screen, with twenty opening effects (Fluid, Genie,
Bounce, Matrix, Fireworks, Blackhole, Beams and more) in one list in ⚙ > Effects, and a Reduce motion switch that opens and
closes it at once.

**Finding apps.** Type to filter the tiles, or every installed app; the most used (or most recent) apps show in a captioned
row. **Ctrl+A** shows every app; **?** lists the keyboard shortcuts; the Menu key or Shift+F10 opens the menu of a tile.

**The bar button.** Left click toggles, middle click opens all apps, right click opens a small menu: Settings, Reload, About and
the version. **Super** alone opens the launcher: the first start asks (a switch, on by default) before it writes that shortcut
into `~/.config/hypr/bindings.lua`; nothing is written to your configuration without it.

**Yours.** Dark and Light, following the Omarchy theme (including the ones Omarchy generates from a picture), every colour
editable; one plain `config.toml`, export / import, and Reset to factory settings (it keeps a copy of everything).
