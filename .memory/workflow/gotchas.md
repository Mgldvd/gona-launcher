# Gotchas

The QML traps (`ColorGroup`, transparent window, `Loader` focus, `FileView` first path, `Qt.quit()` in tests, inline
`component` types) are in [docs/development.md](../../docs/development.md#conventions) and
[docs/architecture.md](../../docs/architecture.md#two-layer-shell-windows). These are the others.

- `JsonAdapter` hands JSON arrays inside a `var` over as Qt lists (`Array.isArray()` false): round-trip through
  `JSON.stringify` (`settingsSnapshot()`, `loadPanels(JSON.parse(JSON.stringify(panels)))`).
- Never pass a file's text as a command argument (`/proc/<pid>/cmdline` is readable by every process, and the marketplace
  review flagged it for `bindings.lua`, which can hold tokens; it also hits the argument size limit). Write with
  `writeFile()` (a throw-away `FileView`, `blockWrites`, not atomic so a symlinked dotfile stays one; `FileView` never writes an empty text, so `""` goes as a newline); it has returned once
  the file is written, so a following `execDetached` (`mv`, `hyprctl reload`) cannot race it. Two `execDetached` calls
  still race each other: those go in one `sh -c`.
- Shell in this repo: avoid heredocs containing `$(...)` and complex `sed` on QML files (they hung or blanked lines
  before); prefer Edit/Write. `cp` is aliased to interactive: use `/bin/cp -f`.
- `~/.config/omarchy/plugins/<id>/` may contain **no symlinks at all** (`omarchy plugin validate` runs
  `find -type l`): sync with `tools/install.sh`, never `ln -s`.
- Plugin ids may not use `omarchy.*` (reserved); this one is `gona.launcher`.
- `.agents/` and `.claude/` are assistant skills, not project code.
