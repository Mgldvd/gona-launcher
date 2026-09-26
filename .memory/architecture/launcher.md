# Launcher: strip, keys, Super, filter, tile size

For a person: the strip, keys and search in [docs/usage.md](../../docs/usage.md). Only the internals are here.

## Strip

- Power buttons run `omarchy-system-shutdown` / `-reboot` / `-logout`; each button has its own switch
  (`allAppsButton`, `powerOffButton`, `restartButton`, `logoutButton`); `stripOn` is any of them.
- Images come from `app/assets/icons/themes/<iconTheme>/` (`stripIcon()`/`iconFor()`, styles in `iconThemes`). The
  stroke-only `line`/`line-square` have a `-dark` twin (same drawings in `#1e1e2e`) that `iconFor()` uses when the
  surface under the buttons is light (`stripLight`: `powerBg` over the launcher background).
- ⚙ > Buttons: `ButtonsPreview.qml` shows the strip on its real `powerSide`, faded while no button is on; nothing in
  that tab is hidden or disabled while the strip is off.
- All apps sets `allAppsOpen`; `flip` (0..1) turns `Node` and the `SearchResults` loader with two `Rotation`s in
  `LauncherContent.qml`. `searchingAll` (typing with search on, all apps open, or flipping back) is what selection and
  list code read; `typedSearch` is the typing case alone.
- `Overlay.iconFor()` returns a full `Qt.resolvedUrl`: a path handed to another file must be absolute.

## Keyboard shortcuts

- `keyActions` in `Overlay.qml`, stored as `keys` (overrides only). `handleKey(event)` runs them and is called from
  `LauncherContent.qml` **and both menus** (whichever has focus needs its own `Keys.onPressed`).
- Combinations need Ctrl or Alt (`KeyCombo.comboProblem()`); plain letters/digits belong to the type-to-filter.
  Recording: `captureAction` / `captureKey`.

## Super alone

A Hyprland binding, not a `keyAction`. Why: [decisions/0003-super-key-in-bindings.md](../decisions/0003-super-key-in-bindings.md).

- The block between `-- >>> gona-launcher:super >>>` / `-- <<< gona-launcher:super <<<` in
  `~/.config/hypr/bindings.lua`; `KeyCombo.superModeOf()`/`withSuperMode()` read and rewrite it, the rest untouched.
- `setSuperMode("off"|"tiles"|"allApps")` writes it and runs `hyprctl reload` in the same command.
  `refreshSuperKey()` (at load and every `open()`) only READS it (and records a block that is already there); nothing adds
  it on its own: the first start's welcome switch (`welcomeSuper`, on by default, `applyPreset()`) or ⚙ > Keys does, because
  the Omarchy marketplace asks that a plugin not change user configuration without explicit consent. `stateDir/super-key`
  remembers the choice, so "Off" sticks. Tests: `welcome-super.body`, `super-key*.body`. The file is the only record (not config.toml, same in every profile).
- A Super-alone bind for `gona.launcher` written by hand outside the block is deleted when the block is written:
  two binds on one release toggle twice, so the launcher opens and closes at once ("it does not appear").
- UI: the accent-framed first row of ⚙ > Keys. Tests: `tests/ui/super-key*.body`, `logic.test.mjs`.

## Filter and selection

Typing sets `filterText`. With `searchAll`, `SearchResults.qml` replaces the tiles; its cells register in
`shell.searchCells`, not `shell.cellItems`, so arrow navigation (`selectDir`) and drag stay separate.

## Tile minimum size

`minH()`/`minW()`/`leafMinH()`/`leafMinW()` in `layout.js` mirror how `Node.qml` wraps cells (gap 4) given
`shell.sizing`; `effRatio()` keeps dividers off that minimum (display and drag); `minWinW`/`minWinH` stop the grip
below it. Every padding comes from one setting, `tiles.padding` (`sizing.pad`): the tile's sides and bottom, its top
through `padTop()` (a title or the Launch all corner keep 30 px), the room around an icon (`cellPad()`, 12 at most)
and `outerMargin` around the tiles. `Node.qml`, `AppCell` (through `cellWidth`/`cellHeight`), `LauncherContent` and
`TilesPreview` all read those; one computed by hand anywhere breaks the minimum sizes.
A tile takes room only for its **installed** apps: `sizing.count` (`installedCountIn()` in `Overlay.qml`) is what
`leafMinH`/`leafMinW` count, not `spec.ids.length` (a preset lists alternatives, and counting the missing ones pushed
the dividers so a tile with one icon got a big box while others cut their icons off). It ignores the type-to-filter, so
tiles do not jump while typing. `tests/ui/preset-fit.body` applies every preset and fails if a tile scrolls.

**Icons never get cut off.** The dividers only keep a tile at the size its icons *want* (`spec.icon` or the global size);
a panel's height is a percentage and a window can be small, so a tile can still be too small. `Node.qml` then shows
`leaf.size` = `Tree.fitIcon()` (through `shell.fitIcon()`): the largest size at most the wanted one at which the
tile's installed apps fit the room inside its padding, never below `shell.minIcon` (24; below that the tile
scrolls). It depends only on the tile's own size and installed count, so it does not feed back into the layout.
Everything drawn in a tile uses `leaf.size`, never `spec.icon`. Tests: `tests/ui/icon-fit.body`, `logic.test.mjs`.

## Corners

Square by default, like Omarchy's windows (`tiles.corner_radius` = 0). Only three things may round: the tiles
(`tileRadius`), the launcher's own surfaces through `shell.corner` (= min(tileRadius, 12): card, selection, all-apps
list, picker, filter box, tips) and the strip buttons through `shell.stripRadius()` (their button style). The ⚙ / ⋯
menus, the welcome screen, the controls and the previews' frames use `radius: 0`; a new rounded shape anywhere else
breaks `tests/ui/corners.body` or the look. Previews that draw tiles follow `tileRadius`.

## Shortcut card (?) and the tile menu from the keyboard

`?` (only with an empty filter and no picker) or F1 sets `shell.helpOpen`; `menus/Help.qml` (rows: `HelpRow.qml`) lists
`keyActions` with `comboFor()` plus the fixed keys, and any key (`LauncherContent.qml`'s `Keys.onPressed`, first lines), Esc or a
click closes it. The Menu key and Shift+F10 call `openSelectedTileMenu()` (`pathOfApp(selectedId)`, the first tile when
nothing is selected). A new fixed key goes in both `Help.qml` and `docs/usage.md`. `tests/ui/help.body`.

## Tile buttons (＋ ⋯) and right-click

The buttons cover the icons of a tight tile (the Dock), so `Node.qml` shows them only when `leaf.controlsOn`: the tile's
menu is open, or the pointer is over it and either the tile has no installed app (`emptyTile`, nothing to cover) or
`shell.tileButtons === "pause"` and the pointer has rested `shell.tileButtonsDelay` (7000 ms, the user's choice: shorter ones were too quick, `restTimer` → `leaf.rested`,
reset when it leaves). `tiles.buttons = "click"` never shows them on hover. A `TapHandler` for the right button on the leaf
calls `openTileMenu()` (a toggle) in every mode; `AppCell`'s `MouseArea` takes only the left button, so a right-click on an
icon reaches it too. Test: `tests/ui/tile-buttons.body` (it moves the pointer off the tile first: the real pointer may be on it).
