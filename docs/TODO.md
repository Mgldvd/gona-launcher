# TODO

Nothing is open. Everything that can be checked without a person's hands was checked, and the rest is written down
below as not going to be done, so it does not come back as a pending item.

## Checked

- `tests/ui.sh`: every UI test passes (a throw-away instance: menus and their nine tabs, Dark / Light and the Omarchy
  theme, colours, profiles and Ctrl+P, presets and the first start, usage history and its row, undo, the reload of
  `config.toml`, the monitor, Super alone, the opening effects in every position, panels, all apps).
- In the real shell (through `omarchy-shell shell summon`, read with `grim`, never with keys): all nine tabs of ⚙ open
  and render; `{"profile":"work"|"top"|"next"|"default"}` switches profile and the one in use is remembered; the
  Super binding is registered once (`hyprctl binds`) and `hyprctl configerrors` is empty.

- A fresh clone of `master` (over SSH) passes `omarchy plugin validate` and its `app/` is identical to `dev`'s; the CI workflow
  (`verify`) passes on GitHub; `v1.0.0` is tagged on `master` with a GitHub release.
- The repository is public; an unauthenticated clone of `master` validates, and `omarchy plugin add` of the HTTPS URL into an
  empty `HOME` installs it (the first start in a throw-away instance is `tests/ui/welcome*.body`).
- Submitted to the Omarchy marketplace: [omacom/omarchy-plugin-marketplace#8851](https://github.com/omacom/omarchy-plugin-marketplace/issues/8851)
  (Desktop; tags launcher and bar). Validation and the automated security baseline pass; a maintainer decides the listing.

## Checked by hand by the owner

The bar button's three clicks and its small menu (Settings, Reload, About, version), the right-click and the seven-second
pause of a tile's ＋ ⋯ buttons, and Super alone, on the real desktop. Nothing was reported wrong.

## Not doing

There is no safe way to press a bar button or a key on the live session from here (see
[.memory/workflow/live-shell.md](../.memory/workflow/live-shell.md)), and a manual test round was ruled out. These stay
covered by the automatic tests only:

- **Effects starting from the bar button's real position** on every kind of bar (bottom, sides). The launcher's side is `tests/ui/bar-anchor.body` and `tests/ui/effects*.body`; `tests/ui/reload-payload.body` covers Reload. The launcher's side
  is `tests/ui/bar-anchor.body` and `tests/ui/effects*.body`; the button's position is `BarWidget.qml` (if it comes out
  wrong, the fix is there).
- **Every monitor layout**: this machine now has two (eDP-1 and HDMI-A-1), so the launcher's choice of the focused monitor is seen for real, but not switching between them. `tests/ui/screen.body` covers the choice of screen.
- **Switching the live desktop to a light Omarchy theme** to look at Colors: it changes the person's whole desktop.
  `tests/ui/theme-light.body` and `theme-dark.body` cover it.
- **A fresh Omarchy install** for the presets: `tests/ui/welcome.body` starts with no `config.toml`, as a new install does.
- **Typing values, Export / Import and launching apps by hand**: `config.body`, `menu*.body` and `usage*.body` do it
  with real key events.

## Decided against

- Collapsing the Opacity row of each colour field until it is touched: it would make the Colors tab
  change height, and every tab shares one height on purpose.
- A ⚙ button inside the launcher: opening the menu is the bar's right click or its shortcut, as
  designed (reconsider only if discoverability turns out to be a problem).
- Keeping the undo history across a restart: it lives in memory, 50 steps, and is not written to any file.
- "Start with system", the tray icon and the autostart entry: the Omarchy shell already runs at
  login and loads the plugin once it is enabled.
