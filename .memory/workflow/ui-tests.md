# UI tests

How to run them and what they need is in [docs/development.md](../../docs/development.md#tests); the test format and
every directive (`// edge:`, `// fixture:`, `// where:`, `// omarchy:`, `// config:`, `// profile:`, `// usage:`,
`// hypr:`, `// open:`) are documented at the top of `tests/ui/run.py`.

- The body runs inside a `TestCase` injected into a copy of `Overlay.qml` (or `OptionsMenu.qml` with `// where: menu`),
  so it sees the file's own ids (`root`, `menu`, `page6`, `fx`, ...). End with `finish()` (the runner stops
  the instance on `UI-DONE`).
- With `fixture: none` the runner writes a comment-only `config.toml`, so the welcome screen does not cover the
  launcher; `// fixture: first-run` leaves it out (`tests/ui/welcome*.body`).
- The runner puts a no-op `hyprctl` first on `PATH`, so a test never reloads the real Hyprland; `// hypr: yes` gives
  the test HOME a `~/.config/hypr/bindings.lua`.
- Covered today: Esc and typing in every mode, Esc after a menu, panel size per position, config.toml written /
  exported / imported / refused / broken, legacy JSON migration, the ⚙ menu by keyboard and mouse, profiles, usage,
  the bar anchor, Dark/Light/Omarchy colours, undo, every effect in every position, the Super key, the welcome screen
  and presets, a tile with only uninstalled apps.
