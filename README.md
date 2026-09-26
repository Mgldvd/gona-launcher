# Gona Launcher

<p align="center">
  <a href="#video"><img src="https://github.com/user-attachments/assets/8af8e69a-73dc-43f0-9803-a2ccc85dcbd6" alt="Gona Launcher in under a minute: opening from the bar, filtering, every installed app, twenty opening effects, creating and organising tiles, Dark and Light, ready-made profiles" width="760"></a>
  <br><sub>The launcher running, under a minute (<a href="#video">full video</a>).</sub>
</p>

**Highly configurable, and made to fit you: one tap of Super away.** Gona Launcher is an app launcher for
[Omarchy](https://omarchy.org): put your apps in tiles you split, colour and arrange yourself, and open them all
with a single tap of Super. Twenty opening effects, ready-made profiles to start from, your own profiles for work and play, and Dark and
Light looks that follow your Omarchy theme.

This branch (`master`) holds only the plugin as it is installed. The source with its docs, tests and tools is on
the [`dev` branch](https://github.com/Mgldvd/gona-launcher/tree/dev).

## Install

```sh
omarchy plugin add https://github.com/Mgldvd/gona-launcher.git --enable
```

Requires **Omarchy 4.0**; there are no other dependencies (the compiled effect shader ships with it). On the first start
you choose how the launcher looks, and a switch there, **on by default**, adds the shortcut **Super alone** (press and release
it) to `~/.config/hypr/bindings.lua`, in a marked block of its own; nothing is written to that file without it. Change or
remove it any time in ⚙ > Keys, the first row. Right-click on the bar
button opens a small menu (Settings, Reload, About, version). How to use it: [docs on `dev`](https://github.com/Mgldvd/gona-launcher/blob/dev/docs/usage.md).

Update it with `omarchy plugin update gona.launcher`: it shows what changed and asks first (the [changelog](CHANGELOG.md) says
what each version brings, and the version is at the bottom of the bar button's right-click menu). If the launcher looks unchanged
afterwards, `omarchy restart shell` loads the new code.

## Video

https://github.com/user-attachments/assets/9bc50db2-94d1-4847-b65a-ac4e07d48a73

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/01-tiles.png?raw=true" alt="Four coloured tiles of apps, with the button strip and profile buttons below"><br><sub><b>Tiles.</b> Group your apps, name and colour each tile.</sub></td>
    <td width="50%"><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/02-filter.png?raw=true" alt="Typing a letter filters the tiles"><br><sub><b>Type to filter</b> the apps in your tiles.</sub></td>
  </tr>
  <tr>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/03-all-apps.png?raw=true" alt="Every installed app in one grid"><br><sub><b>All apps.</b> Every installed app, one button away.</sub></td>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/04-all-apps-search.png?raw=true" alt="Searching every installed app for &quot;dis&quot;"><br><sub><b>Search</b> among all installed apps.</sub></td>
  </tr>
  <tr>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/05-effect-blackhole.png?raw=true" alt="The Blackhole opening effect swallowing the tiles"><br><sub><b>Opening effects.</b> Twenty of them, here Blackhole.</sub></td>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/06-tile-menu.png?raw=true" alt="The menu of one tile: split, add apps, icon size, alignment"><br><sub><b>Tile menu.</b> Split, add apps, icon size, title, colours.</sub></td>
  </tr>
  <tr>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/07-split-tile.png?raw=true" alt="A tile split in two, the new half empty"><br><sub><b>Split</b> a tile right or down, drag apps in.</sub></td>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/08-colours.png?raw=true" alt="Tiles named Work, Social and Notes in different colours"><br><sub><b>Colours.</b> A border and background for every tile.</sub></td>
  </tr>
  <tr>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/09-light.png?raw=true" alt="The same tiles in the Light look"><br><sub><b>Dark and Light</b>, or following the Omarchy theme.</sub></td>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/10-profiles.png?raw=true" alt="A second profile with its own tiles, and its button lit in the strip"><br><sub><b>Profiles.</b> Several saved setups, one key each.</sub></td>
  </tr>
  <tr>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/11-add-apps.png?raw=true" alt="The app picker: every installed app to add to a tile, with a search field"><br><sub><b>Add apps</b> to a tile from every installed app.</sub></td>
    <td><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/12-settings.png?raw=true" alt="The settings menu on its Colors tab: Dark and Light previews, palette swatches and opacity sliders"><br><sub><b>Settings.</b> Nine tabs, a live preview in each.</sub></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="https://github.com/Mgldvd/gona-launcher/blob/dev/docs/media/screenshots/13-welcome.png?raw=true" alt="The welcome screen: five ready-made profiles (Omarchy, Top, Dock, Focus, Clean), each with a picture of how it looks" width="70%"><br><sub><b>Ready-made profiles.</b> Start from Omarchy, Top, Dock, Focus or Clean; the others can be added as profiles.</sub></td>
  </tr>
</table>

## Uninstall

Set ⚙ > Keys > "Open with Super" to **Off** first (or delete the `gona-launcher:super` block from
`~/.config/hypr/bindings.lua`), then:

```sh
omarchy plugin remove gona.launcher
rm -r ~/.config/gona-launcher ~/.local/state/gona-launcher    # optional: settings, tiles, profiles, usage counts
```

## What it touches

Its own settings in `~/.config/gona-launcher/` and its state in `~/.local/state/gona-launcher/`; and, only if you leave the
switch above on (or set it in ⚙ > Keys), the marked `gona-launcher:super` block in `~/.config/hypr/bindings.lua`
(followed by `hyprctl reload`). It makes no network requests of its own (About opens the project page in your browser) and asks for no elevated privileges.

## License

Dual-licensed under either the [Apache License 2.0](LICENSE-APACHE) or the [MIT License](LICENSE-MIT), at your option.
