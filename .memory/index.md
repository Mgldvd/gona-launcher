# .memory

Working notes for whoever changes the code (agents included): how to work against the live shell, the traps, and the
internals that `docs/` does not describe. `docs/` is for people using or reading about the plugin; nothing here repeats
it. When a fact belongs to a person reading the docs, it goes in `docs/` and is linked from here, never copied.

Read the file for the area you are about to touch, not all of them.

| File | Read before |
|---|---|
| [workflow/live-shell.md](workflow/live-shell.md) | Installing, testing or looking at the plugin in the running shell |
| [workflow/gotchas.md](workflow/gotchas.md) | Editing QML, shell commands in this repo, the plugin folder |
| [workflow/ui-tests.md](workflow/ui-tests.md) | Writing or running `tests/ui/*.body` |
| [architecture/state.md](architecture/state.md) | Settings, config.toml, the tile tree, undo, profiles, usage |
| [architecture/windows.md](architecture/windows.md) | `launcherWin`/`menuWin`, focus, stacking, panel placement, the bar button |
| [architecture/colors.md](architecture/colors.md) | Colour fields, Dark/Light, the Omarchy theme, text contrast |
| [architecture/effects.md](architecture/effects.md) | The opening effects, `FxLayer`, the shader |
| [architecture/menus.md](architecture/menus.md) | The ⚙ and ⋯ menus, their controls and previews |
| [architecture/launcher.md](architecture/launcher.md) | Strip, keyboard shortcuts, Super alone, filter and selection, tile minimum size |
| [decisions/](decisions/) | Why things are the way they are (Omarchy port, one launcher window, Super key, master = production) |
