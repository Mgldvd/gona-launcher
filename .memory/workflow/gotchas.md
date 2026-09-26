# Gotchas

The QML traps (`ColorGroup`, transparent window, `Loader` focus, `FileView` first path, `Qt.quit()` in tests, inline
`component` types) are in [docs/development.md](../../docs/development.md#conventions) and
[docs/architecture.md](../../docs/architecture.md#two-layer-shell-windows). These are the others.

- `JsonAdapter` hands JSON arrays inside a `var` over as Qt lists (`Array.isArray()` false): round-trip through
  `JSON.stringify` (`settingsSnapshot()`, `loadPanels(JSON.parse(JSON.stringify(panels)))`).
- Two `Quickshell.execDetached` calls race: a write and a move/reload go in **one** `sh -c`
  (`renameProfile()`, `setSuperMode()`).
- Shell in this repo: avoid heredocs containing `$(...)` and complex `sed` on QML files (they hung or blanked lines
  before); prefer Edit/Write. `cp` is aliased to interactive: use `/bin/cp -f`.
- `~/.config/omarchy/plugins/<id>/` may contain **no symlinks at all** (`omarchy plugin validate` runs
  `find -type l`): sync with `tools/install.sh`, never `ln -s`.
- Plugin ids may not use `omarchy.*` (reserved); this one is `gona.launcher`.
- `.agents/` and `.claude/` are assistant skills, not project code.
