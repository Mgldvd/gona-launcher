# Using the launcher

## Opening it

| How | What happens |
|---|---|
| Left click on the bar button | Toggles the launcher. It opens on the screen of that bar, and comes out of the button in the effects that start from one |
| Right click on the bar button | A small menu: **Settings** (the launcher with its ⚙ menu; there is no ⚙ button inside the launcher), **Reload** (reads the configuration, profiles and usage from disk again), **About** (opens the project page) and the **Version** |
| Middle click on the bar button | Opens straight into "All apps" |
| Press and release **Super** alone | Toggles the launcher, once you turn it on (optional, off by default: the first start's welcome screen, or ⚙ > Keys, first row: Off, Tiles or All apps) |
| `omarchy-shell shell toggle gona.launcher` | Opens it, or closes it if it is open. `summon` opens and `hide` closes, without flipping |

**Super alone** is a Hyprland binding the plugin keeps in `~/.config/hypr/bindings.lua`, between the lines
`-- >>> gona-launcher:super >>>` and `-- <<< gona-launcher:super <<<`. It is written only when you ask for it: a switch on the first
start's welcome screen (off until you turn it on, shown only when that file exists), or ⚙ > Keys > "Open with Super" later,
which rewrites or removes the block. Loading the plugin, Esc on the welcome screen and a factory reset never touch the file,
and nothing outside the block is ever changed. If you already have a Super-alone line of your own for the launcher, it is left
as it is and no block is added (both together would open and close it at once); ⚙ > Keys says so. It fires on release, so Super with another key still does what
it did. It is the same in every profile.

To use another key, bind the command in Omarchy's keybinding settings. The command takes a JSON payload:

```sh
omarchy-shell shell toggle gona.launcher '{"allApps":true}'        # straight into "All apps"
omarchy-shell shell summon gona.launcher '{"options":true}'        # with the ⚙ menu
omarchy-shell shell summon gona.launcher '{"tab":"effects"}'       # the ⚙ menu on a tab: tiles, colors, window, effects, search, buttons, keys, menu, profiles
omarchy-shell shell summon gona.launcher '{"profile":"work"}'      # on a saved profile ("default", "next", "previous")
omarchy-shell shell summon gona.launcher '{"presets":true}'        # with the ready-made profiles to add (see below)
```

The launcher opens on the monitor Hyprland has focused, or on the bar's screen when opened from the bar button.

## Profiles and ready-made profiles: the first start

The first time the launcher opens (there is no `~/.config/gona-launcher/config.toml` yet), it shows a welcome
screen instead of the tiles: five **ready-made profiles**, each with a small picture of how it looks and how many
of its apps are installed on this computer. There is only one idea to keep in mind: a **profile** is a saved set of
tiles and settings that you switch between (Ctrl+P, the buttons in the strip, or a keybinding). The ready-made ones are
just profiles somebody already made for you: the one you choose becomes your first (the *default*) and you change it as you like.

| Ready-made profile | What you get |
|---|---|
| **Omarchy** (recommended) | The full one: full screen, square corners like Omarchy's windows, seven titled tiles each with its own colour and icons centred: Web, Chat, System on top with larger icons, then Dev, Office, Media & Play and Create, with the apps a fresh Omarchy has. Every option on: the most-used row, search in every app, the all-apps, power and profile buttons, the Beams opening, Dark/Light following Omarchy. The chat tile has "Launch all" |
| **Top** | A panel dropping from the top with the Fluid opening: four titled tiles in their own colours (Web, Work, Media, System), square corners, the all-apps button |
| **Dock** | A dock along the bottom, like macOS's, opening with Genie: one row of your apps in three coloured groups, large icons without names |
| **Focus** | A small centred window with the Bounce opening and one titled row of large icons for the tools to work with: terminal, editor, browser, files, notes |
| **Clean** | One empty tile and the defaults, to build your own from nothing |

The arrows, Tab or 1–5 choose, **Enter** (or a double click) starts with it. "Also add … as profiles" (every card it adds is then marked) adds the
other ones too, as profiles to try with Ctrl+P, in this order with Clean, the empty one, last. **Esc** starts with Omarchy, so the launcher is never left empty;
closing the launcher without choosing brings the screen back the next time.

A ready-made profile's tiles list alternatives (Chromium, Zen, Firefox, Brave…; Foot, Ghostty, Alacritty, Kitty…; Steam,
Heroic, Lutris…). Only the installed ones show, so a tile fills in as you add apps with Omarchy's installers, and
nothing breaks when you remove one (`omarchy-remove-preinstalls` included). A tile whose apps are all gone says so
and offers ＋.

Later, ⚙ > Profiles > **Browse ready-made profiles…** shows the same cards: the one you pick is **added** as a new profile
(named after it, `dock-2` if `dock` exists) and the launcher switches to it. Nothing you have is replaced, and there are at
most 5 profiles, the default included (delete one to add another). Esc cancels. Profiles are listed in the order they were made.

**Starting over.** ⚙ > Profiles > **Reset to factory settings…** (it asks once more) erases your settings, tiles, profiles and
usage history and shows the welcome screen again, exactly as on the first start (**Esc** there starts with Omarchy). Nothing is lost for
good: the whole `~/.config/gona-launcher` folder is copied to `~/.config/gona-launcher.reset-<date>` first, and copying a file
of it back restores it. The Super binding in Hyprland's `bindings.lua` is not touched.

## Where it opens

⚙ > Window > **Mode**: *Centered* (a resizable card in the middle: drag its bottom-left corner), *Top*, *Bottom*,
*Left* or *Right* (a panel on that edge, with its own width, height and edge offset), or *Full screen*. "Open next
to the bar button" centres a panel on the button that opened it. How it comes in and goes out is
[⚙ > Effects](effects.md).

## Tiles

Apps live in **tiles**, and a tile can be split into two, right or down, as many times as you like. Each tile has a
**+** (add apps) and **⋯** (its menu) button in its corner. They appear once the pointer has rested on the tile for about seven
seconds, so they do not cover the icons while you aim at one (in ⚙ > Tiles, *Tile buttons* can turn them off: *Right-click only*).
**Right-clicking a tile** opens its menu at once, always. An empty tile shows its **+** straight away.

- **Add apps**: **+** opens a grid of every installed app with a search box; click an app to add it to the tile (a ✓ marks the ones already there; click again to take it out).
- **Move apps**: drag an icon onto another tile, or onto another icon to place it beside it. Dropping on the left
  or right half of an icon puts it before or after.
- **⋯ menu**: *Split →* / *Split ↓*, *Add apps*, and three tabs: **General** (icon size for this tile, "Launch all
  apps" and "Show as a regular icon", alignment), **Title** (text, font, bold, italic, position) and **Colors** (its
  own border and background). The bottom has *Remove tile* (*Clear tile* for the only one) with a confirmation.
- **Resize tiles**: ⚙ > Tiles > "Resize tiles" turns the dividers into handles you drag; they align with each other
  and a tile is never made smaller than its icons need.
- **Undo / redo**: Ctrl+Z and Ctrl+Shift+Z, or the buttons in ⚙ > Tiles (50 steps, forgotten on restart).

## Finding and launching

- **Click** an icon to launch it. **Arrow keys** move to the nearest app, **Tab** / **Shift+Tab** step through them,
  **Enter** launches the selected one (**Space** too, while no filter is typed), **Alt+1 … Alt+9** select the
  *n*-th app of the tile that has the selection.
- **Type to filter**: letters and digits start a filter (shown in a box at the top), Backspace removes a character. With
  ⚙ > Search > "Allow all apps in search" the matches are every installed app, not only your tiles, in the order set
  by "Order of all apps and search results" (name, most used, most recent).
- **All apps** (Ctrl+A, or the strip's button) shows a list of every installed app. The list, and the matches among
  all apps while typing, take the whole screen whatever the mode (a dock or a small window has no room for them): the
  launcher grows from its own shape to the screen while the tiles fade out and the list zooms in, and shrinks back
  the same way.
- **Esc** goes back one step at a time: a shortcut being set, the ⚙ or ⋯ menu, the filter or selection, "All apps",
  resize mode, the app picker, and finally closes the launcher. A click outside the launcher closes it too.
- **Ctrl + wheel** or **Ctrl +** / **Ctrl −** / **Ctrl 0** change the icon size. Whatever the size, a tile shrinks its icons when its apps do not fit, so none is ever cut off or touches its edge; add an app and the icons of that tile get smaller, remove one and they grow back.
- The launcher counts what you launch from it (on this machine only) to order the lists; ⚙ > Search turns that off
  or clears it, and can show a row of your most used (or most recent) apps above the tiles. The row is captioned *Most used* (or *Recently used*) at its left and only fills in as you launch apps, so it starts empty; an app can be in both the row and its tile.

## The strip

An optional strip of buttons: **All apps**, **Shut down**, **Restart**, **Log out** (Omarchy's own
`omarchy-system-shutdown` / `-reboot` / `-logout`), and, if you turn them on, your saved **profiles**. Each button is
switched on in ⚙ > Buttons (the profile buttons too, once you have saved a profile in ⚙ > Profiles). It sits below the tiles in a centered or full-screen
launcher, and on the side opposite the edge of a panel. Seven styles (Square line, thin square outlines, is the default), sized in ⚙ > Buttons.

## Keyboard shortcuts

Configurable in ⚙ > Keys (click one, press the new combination; it needs Ctrl or Alt).

| Action | Default |
|---|---|
| Show all apps | Ctrl+A |
| Open / close the ⚙ menu | Ctrl+, |
| Switch Dark / Light | Ctrl+T |
| Next / previous menu tab | Ctrl+PgDown / Ctrl+PgUp |
| Next / previous tile | Ctrl+Tab / Ctrl+Shift+Tab |
| Shut down / Restart / Log out | Ctrl+Shift+P / Ctrl+Shift+R / Ctrl+Shift+L |
| Next profile | Ctrl+P |
| Undo / redo tile change | Ctrl+Z / Ctrl+Shift+Z |

Fixed: the arrows, Tab, Enter, Space, Esc, Ctrl +/−/0, Alt+1 … 9, the **Menu key** or **Shift+F10** (the menu of the tile that holds the
selected app, so the tile menu needs no mouse) and **?** or **F1**, which list every shortcut on a card over the launcher (any key or a
click closes it; a `?` typed while filtering is just a character).

## The ⚙ menu

Nine tabs, each with a live preview where it helps. Every slider has a ↺ to reset it and its number can be clicked
and typed; **Tab** reaches every control, arrows and Space change it; "Reset this tab" and "Done" (like Esc) are at
the bottom. Drag the menu by its top strip.

| Tab | What is in it |
|---|---|
| **Tiles** | Icon size, names, gap, padding, corner roundness, border width; resize tiles; undo / redo |
| **Colors** | Dark, Light or Auto, "Follow the Omarchy theme", and the looks, each with its own accent, border, tile background and gap colours from 8 palette colours or any colour, with opacity. Text colour follows the surface it sits on |
| **Window** | Mode, next to the bar button, panel width and height, edge offset |
| **Effects** | How it opens and closes: [twenty effects](effects.md), duration, animate closing |
| **Search** | Filter text size, search every app, names, order, remembering launches, the row of most used apps |
| **Buttons** | The strip: which buttons, size, style, background |
| **Keys** | "Open with Super" first (Off, Tiles, All apps), then the shortcuts above |
| **Menu** | The menu's own background and size |
| **Profiles** | Your profiles (save a copy, switch, rename, delete, their buttons), adding a ready-made profile, export / import of the configuration, and "Reset to factory settings" |

With **Follow the Omarchy theme** on, the eight palette colours and the "system" backgrounds are those of the active
Omarchy theme (`omarchy theme set …`) when its light or dark mode matches the look in use; otherwise the launcher's
own palettes. A theme change shows the next time the launcher opens.

## Profiles

A profile is a saved configuration, settings and tiles (`~/.config/gona-launcher/profiles/<name>.toml`): one for
work, one for games. ⚙ > Profiles saves, renames, switches and deletes them; Ctrl+P cycles; the payload above
opens the launcher on one, so a keybinding can open a different launcher each. See
[configuration](configuration.md#profiles).
