# The ⚙ and ⋯ menus

What each tab holds, for a person: [docs/usage.md](../../docs/usage.md#the--menu). The overview (nine tabs, equal
height, dimmed rows, `m…` colours): [docs/architecture.md](../../docs/architecture.md#menus).

- Tabs are `OptionsMenu.qml`'s `tabs`, each with a `key` that `Overlay.resetTab()` understands. `MenuTabBar.qml` draws
  each as a line icon (`MenuIcon.qml`, `menuIcons.js`) over its label.
- 720 px wide, rows flowing into two columns (`MenuSection.qml`, `colW`, `colGap` 16). Every page is `pageH` tall (the
  tallest page's `natural` + 16). **Keep the tallest under ~500 px** so the menu fits 768 px at 100 % "Menu size";
  past `maxHeight` it scrolls and the bottom row is cut. `tests/ui/super-key-menu.body` checks `pageH < 520`.
- Rows that do not apply are `enabled: false` (dimmed), never hidden, so nothing jumps.
- Tiles, Colors, Window, Effects and Buttons open with a live preview (`menus/previews/`) drawn from the same settings
  and colours the launcher resolves; the ⋯ menu shows its tile in miniature.
- Every slider has ↺ (`SliderRow.showReset`/`resettable`, from `Overlay.defaults`/`isDefault()`/`resetSetting()`);
  its number is typable (`SliderValue.qml`). Bottom row: "Reset this tab" (`resetTab()`) and "Done" (like Esc).
- Keyboard: Tab reaches every control (`activeFocusOnTab`, `FocusRing.qml`); a text field that lets go of the focus
  calls `shell.menuFocusRequested()` so the menu keeps the keys. Both menus have their own `Keys.onPressed` calling
  `shell.handleKey()`.
- Controls are files of their own (`menus/controls/`), each taking `shell` and `fullWidth`. **Do not bring inline
  `component` types back into the two menu files**: hot reload then serves a stale compile.
- "Menu size" (`menuScalePct`/`menuScale`/`setMenuScale()`) scales both menus about their centre; while its slider is
  dragged only the number follows (`SliderRow.dragging`), the scale applies on release.
- `menuWin` is centred with a `Binding` until dragged by its header strip (`userMoved`). `TileMenu.qml` has three tabs
  (General, Title, Colors), the same `scale` and `menuBg`.
- Payload `{"options":true}` opens the ⚙ menu, `{"tab":"<key>"}` on that tab.
