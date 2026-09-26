# Windows, focus and stacking

The overview (`launcherWin` with `card`/`dockedArea`/`fx`, `menuWin`, the anchors and `Loader` traps) is in
[docs/architecture.md](../../docs/architecture.md#two-layer-shell-windows). Why it is one launcher window:
[decisions/0002-one-launcher-window.md](../decisions/0002-one-launcher-window.md).

- Both windows are wlr layer-shell surfaces on `WlrLayer.Overlay`. A plugin can only make layer-shell surfaces, never a
  real OS window, so the centred `card` with its resize grip (bottom-**left**; ⚙ lives bottom-right) is the closest to
  a floating window. The grip drags `winW`/`winH`, clamped to `minWinW`/`minWinH` and the screen.
- `launcherWin` is mapped while `root.opened || root.slide > 0.001`, whatever the `edge`. Its screen-wide scrim
  `MouseArea` closes the launcher on a click `card`/`dockedArea` does not cover.
- Only one of `launcherWin`/`menuWin` claims `WlrKeyboardFocus.Exclusive` at a time; `root.anyMenuOpen` arbitrates.
- **Stacking is by mapping order, not QML.** Same-layer surfaces stack in the order each last became `visible`
  (`hyprctl layers` shows it), and *any* invisible → visible flip is a fresh mapping that can jump above an open menu.
  `open()` sets `opened` (maps `launcherWin`) **before** `optionsOpen`/`allAppsOpen` (can map `menuWin`); swapped, the
  ⚙ menu opens behind the tiles with every property `true` and nothing in the log. Before changing any property that
  gates a *different* surface's `visible`, ask what else might (re)map at that moment.
- `dockedArea` is placed with `x`/`y` bindings and sized to `panelW`/`panelH` % of the screen. Each edge keeps
  `panels[edge] = [w%, h%, offset px?]`; the offset falls back to `sharedOffset` (also full screen's).
- The strip (`stripOn`) sits on `powerSide`, opposite the docked edge (below for `card` and `full`), growing
  `dockedArea` by `powerPad`.
- **Next to the bar button**: `BarWidget.qml`'s left click sends `{"anchor":{"x","y","screen"}}` with `toggle`;
  `open()` keeps it in `anchorPos` (null from a key) and opens on that screen. With `nextToBar` a top/bottom panel
  centres on the button along the edge, a left/right one on its height, clamped (`dockedArea.atButton`); card and
  full screen ignore it. The bar-widget part is only checked by hand (`tests/ui/bar-anchor.body` sends the payload).
- `targetScreen` is set by `open()` from `focusedScreen()` (Hyprland's focused monitor via `Quickshell.Hyprland`, else
  the first) each time it opens from closed, never while open.
- Lifecycle: the shell calls `open(payload)`/`close()` on `Overlay.qml`'s root and builds `toggle` itself from
  `opened`, so there is no `toggle()` to define. Payload keys are listed in `docs/architecture.md`.

## Growing to the screen for all apps

`edge` never changes for "All apps": `flip` (0 tiles → 1 all apps, 420 ms) drives `grow` (0 in full screen), and
`card` / `dockedArea` interpolate (`lerp`) from their own rect (`ownX/ownY/ownW/ownH`) to the whole screen, the same
window and Loader all along, so nothing is rebuilt. In `LauncherContent` the tiles keep `ownContentW/H` while they
fade out, and `SearchResults` is laid out at `fullContentW/H` and scaled to fit, so neither re-flows per frame. The
strip stays on its own side. Anything new that places the launcher must add the same `lerp` by `grow`
(`tests/ui/allapps-full.body` checks the size halfway).

## The bar button's right-click menu

`BarWidget.qml` opens an Omarchy `PopupCard` (from `qs.Ui`, the same card the clock and media widgets use: it closes on a
click outside or when another bar popup opens) with Settings, Reload, About and the version. Settings and Reload are
`omarchy-shell shell summon gona.launcher` with `{"options":true}` / `{"reload":true}` (`Overlay.reloadAll()` reads
config.toml, usage, profiles, theme and Super from disk again; `tests/ui/reload-payload.body`). The version comes from a
`FileView` on `../manifest.json` (it only resolves with `manifest.json` one folder above `app/`, as installed).
Nothing in `tests/ui.sh` can click the bar, and its throw-away shell has no `qs.Ui`; to look at the popup, copy the shell's
`Ui/` and `Commons/` next to a `shell.qml` that holds a `PluginBarApi` and a `Loader` of `app/BarWidget.qml` with
`menuOpen = true`, run `quickshell -n -p`, and `grim` it (that is how it was checked).
