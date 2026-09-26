# Configuration

The file format and settings below are those of this version of the plugin (Omarchy 4.0). Everything the launcher
remembers, settings and tiles, is one TOML file:
`~/.config/gona-launcher/config.toml`. It is written by the launcher 0.4 s after a change, and read at start.
Edit it while the launcher is closed, or while it runs: a change on disk is read again (an invalid file is
refused with a message in ⚙ > Profiles, and the file is left alone). A value that is missing, or of the wrong
type, falls back to its default; values out of range are put back in range.

## Settings

| Key | Default | What it does |
|---|---|---|
| `window.mode` | `""` | Where it opens: `""` centered, `top`, `bottom`, `left`, `right`, `full` |
| `window.width`, `window.height` | 900, 620 | Size of the centered window (px) |
| `window.offset` | 12 | Distance from the screen edge for panels and full screen (px); a position can have its own, see `window.panels` |
| `window.effect` | `"classic"` | How it opens and closes, in every mode: `classic` (a panel slides, full screen fades, a centered window appears at once) or one of twenty shader effects, see [effects](effects.md) (⚙ > Effects) |
| `window.effect_ms` | 700 | Length of the shader effects (ms, 0 = instant) |
| `window.animate_close` | `true` | `false`: closing is instant, only the opening is animated |
| `window.reduce_motion` | `false` | `true`: the launcher opens and closes at once, with no effect or slide (⚙ > Effects > Reduce motion); the effect and its length are kept for when it is off |
| `window.slide_speed` | 110 | Classic's entrance time (ms, 0 = instant) |
| `window.full_from` | `"top"` | Side `slide` and `meet` come from (a docked panel slides from its own edge). An old `full_animation` in a file is read once as the effect |
| `window.next_to_bar_button` | `false` | A panel opened from the bar button is centred on that button along its edge |
| `[window.panels]` | see below | Per position `[width %, height %]` (each 5–100) and optionally the offset (px) as a third number |
| `tiles.icon_size` | 48 | Icon size (px): the size a tile shows when its apps fit. When they do not (more apps, a smaller tile or panel) the icons shrink, down to 24 px, so none is ever cut off by the tile's edge |
| `tiles.show_names` | `true` | App names under the icons |
| `tiles.gap` | 8 | Space between tiles (px, up to 100) |
| `tiles.padding` | 14 | Room inside a tile, around each icon and around the tiles (px, 0–24). Lower brings the icons to the border; at 0 they almost touch it. A tile with a title keeps room for it |
| `tiles.corner_radius` | 0 | Corner roundness (px, up to 28). 0 is square, like Omarchy's windows; the launcher's own surfaces (its background, the selection, the all-apps list, the filter) round with the tiles, up to 12. The menus are always square |
| `tiles.border_width` | 2 | Tile border (px) |
| `tiles.buttons` | `"pause"` | When a tile shows its ＋ and ⋯ buttons: `"pause"` (once the pointer has rested on it for about seven seconds, so they never cover an icon you are aiming at) or `"click"` (never on hover). Right-clicking a tile opens its menu with either. An empty tile shows its ＋ at once |
| `search.all_apps` | `false` | Typing searches every installed app, not only the tiles |
| `search.show_names` | `true` | Names in those results |
| `search.text_size` | 14 | Size of the filter box shown while typing (px) |
| `buttons.all_apps`, `.shut_down`, `.restart`, `.log_out` | `false` | Which buttons the strip has |
| `buttons.size` | 34 | Button size (px) |
| `buttons.profiles` | `false` | The saved profiles as buttons in the strip (up to 5, the default included and first) |
| `buttons.profile_labels` | `"numbers"` | `numbers` (1 2 3), `letters` (A B C) or `roman` (I II III); the profile's name shows on hover |
| `buttons.style` | `"line-square"` | `grid`, `pastel`, `carbon`, `line`, `line-square`, `circle`, `metro` |
| `usage.track` | `true` | Count the apps launched, see below |
| `usage.order` | `"most_used"` | Order of the all-apps list and the typed search: `name`, `most_used`, `recent` |
| `usage.show_row` | `false` | A row of the apps used most (or last, with `order = "recent"`) above the tiles |
| `usage.row_count` | 6 | How many apps in that row (3–10) |
| `appearance.mode` | `"dark"` | `dark`, `light` or `auto` (follows Omarchy's own light/dark) |
| `appearance.follow_omarchy` | `true` | Use the colours of the active Omarchy theme when its mode matches |
| `appearance.menu_size` | 100 | Size of the ⚙ and ⋯ menus (%) |
| `[colors.dark]`, `[colors.light]` | `{}` | Colours of each mode, see below |
| `[keys]` | `{}` | Shortcuts that differ from the defaults; `""` turns one off |

`window.panels` starts as `top = [100, 50]`, `bottom = [100, 50]`, `left = [40, 100]`, `right = [40, 100]`.
Each position keeps its own size and offset, so moving between them loses nothing.

### Colours

Under `[colors.dark]` and `[colors.light]`, the fields `accent`, `border`, `bg` (tile background), `appBg`
(the gaps between tiles), `powerBg` (behind the strip's buttons) and `menuBg`. A field is `{ v = ..., a = ... }`
(a table of its own or inline): `v` is `"system"` (the built-in colour), `"none"` (transparent), a palette
number `0`–`7`, or `"#rrggbb"`; `a` is the opacity 0–100. Either part may be left out. A tile can override
`border` and `bg` (`cBorder`, `cBg` in its entry under `[layout]`). The 8 palette colours are the launcher's own
(Dark and Light versions) or, following the Omarchy theme, the theme's accent, red, orange, yellow, green, cyan,
blue and magenta.

### Tiles

`[layout]` is a tree: a split (`type = "split"`, `dir = "h"` or `"v"`, `ratio`, and the two halves as
`[layout.a]` and `[layout.b]`) or a leaf (`type = "leaf"`, `ids = ["desktop-id", ...]`, and optionally `icon`,
`title`, `titleAlign`, `titleFont`, `titleBold`, `titleItalic`, `centerH`, `centerV`, `launchAll`,
`launchAllIcon`, `launchAllIndex`). Use the desktop id of an app (`org.gnome.Nautilus`, without `.desktop`).

## Profiles

A profile is a saved configuration: `~/.config/gona-launcher/profiles/<name>.toml`, same format. `config.toml`
is the default profile. The one in use is remembered in `~/.local/state/gona-launcher/profile`, and edits go to
its file. ⚙ > Profiles lists them, saves the current state as a new one and deletes the one in use.

```sh
omarchy-shell shell summon gona.launcher '{"profile":"work"}'     # switch, then open
omarchy-shell shell summon gona.launcher '{"profile":"default"}'  # back to config.toml
omarchy-shell shell summon gona.launcher '{"profile":"next"}'     # the next one ("previous": the one before), wrapping round
```

Ctrl+P (⚙ > Keys) does the same from inside the launcher. Names are also not `next` or `previous`. ⚙ > Profiles can rename the one in use.

At most 5 profiles exist, the default counting as one (four can be saved). `buttons.profiles` and `buttons.profile_labels` are shared by every profile: switching carries them over. Names are 1–32 letters, digits, `-` or `_`, and not `default`. Bind those commands to keys in Hyprland to open
a different launcher from each.

## Ready-made profiles

The ready-made profiles of the [first start](usage.md#profiles-and-ready-made-profiles-the-first-start) are files of the same
format shipped with the plugin, `app/presets/<name>.toml` (`omarchy`, `top`, `dock`, `focus`, `clean`); they are never
written. On the first start the chosen one is copied into `config.toml` (what it does not say goes back to its default,
and its `[layout]` replaces the tiles); later one is copied into a new `profiles/<name>.toml`. Read them for examples of
a hand-written configuration. The order the profiles were made in is kept in `~/.local/state/gona-launcher/profile-order`.

## Usage history

`~/.local/state/gona-launcher/usage.json` holds `{ "<desktop-id>": { "n": launches, "last": time in ms } }` for
the apps launched from here. It stays on the machine, is not in `config.toml` or in an export, and is used only
for `usage.order`. ⚙ > Search turns counting off and clears it.

## Import and export

⚙ > Profiles > Configuration file. Export copies the profile in use to the path in the field (`~` is the
home folder). Import reads a file from that path, refuses it if it is not valid TOML (with the line), keeps the
current state as `<file>.bak` next to the profile, then replaces the settings and tiles: what the file does not
say goes back to its default, and a file without `[layout]` keeps the tiles on screen.

## Other files

| File | What |
|---|---|
| `config.toml.bak` / `<profile>.toml.bak` | State before the last import |
| `config.toml.broken` | Copy of a `config.toml` that was not valid TOML at start (the launcher then runs on defaults) |
| `window.json`, `layout.json` | Read once, only when there is no `config.toml` yet, by an older version's data; never written |
