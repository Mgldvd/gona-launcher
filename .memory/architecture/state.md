# State: settings, config.toml, tiles, profiles, usage

The overview is in [docs/architecture.md](../../docs/architecture.md#settings-and-saving); the file format, profiles,
usage history and import/export as a person sees them are in [docs/configuration.md](../../docs/configuration.md).
`Overlay.qml` is the only file with state; everything else receives it as `shell`.

## Adding a setting

1. A property in the `saved` `JsonAdapter` (short name, e.g. `icon`).
2. A root `property alias` of it (`iconSize: saved.icon`).
3. `config.js`: `DEFAULTS` and `MAP` (short name → section and key, e.g. `icon` → `[tiles] icon_size`), and `COMMENTS`
   for its `#` line. `tests/logic.test.mjs` fails if `DEFAULTS` and `MAP` disagree.
4. Unless every value of its type is valid, a line in `loadSettings()` that puts it back in range (runs after every load).
5. Its tab's list in `resetTab()`, a row in the tab, and a row in `docs/configuration.md`.

## Saving and loading

- Any `saved` change → `adapterUpdated` → `saveSize` (400 ms) → `saveNow()` → `configFile.setText(configText())`.
  Nothing is written back while `configLoaded` is false (during a load, a switch, an outside edit).
- Load (`Component.onCompleted`): `config.toml` with text → `applyConfigText()`; invalid → defaults, WARN, and a copy
  to `config.toml.broken` first (the next change rewrites the file); no file → `migrateLegacy()` reads `window.json` +
  `layout.json` once (same short names; the old single `powerButtons` becomes the three power switches) and writes it.
- Outside edits: `configFile` is watched; `configEditedOutside()` skips the launcher's own writes (same text as
  `lastWritten`, or within 1 s), refuses invalid TOML with a message in ⚙ > Profiles, and does not rewrite the file
  from what it read, so a person's comments survive until the launcher's next own save.
- `toml.js` is a subset (tables, dotted keys, strings, numbers, booleans, arrays, inline tables); it refuses `[[x]]`,
  multi-line strings and dates, with the line number.

## Tile tree and undo

- Leaf `{type:"leaf", ids:[…], icon?, cBorder?, cBg?, centerH?, centerV?, title?, …}`, split
  `{type:"split", dir:"h"|"v", ratio, a, b}`, addressed by a path of `"a"`/`"b"`. `Node.qml` renders it recursively.
- Every edit is `clone()` → mutate (the `…At` functions of `layout.js`, or directly) → `commit(t)`. **Anything that
  changes tiles goes through `commit()`**: it reassigns `layout`, schedules the save and pushes undo.
- `undoStack`: JSON text, 50 steps, only when the tree really changed; a divider drag is one step (ratios being dragged
  live in `root.live`, committed on release, so tiles are not rebuilt per mouse move). An import clears it, a restart
  forgets it. Ctrl+Z / Ctrl+Shift+Z and buttons in ⚙ > Tiles.

## Profiles

- `activeProfile` ("" = `config.toml`) → `configPath = profilePath(activeProfile)`; everything that saves, watches,
  exports or imports follows `configPath`.
- `switchProfile(name)` writes the profile being left **by its own path** (`writeFile()`: `configFile.setText` would
  follow the new path), loads the other with `applyConfigText()`, carries over `showProfileButtons`/`profileLabels`,
  sets `lastWritten` so the watcher does not read it back, and shows `toast` for 1.8 s.
- `createProfile()` copies what is on screen; `deleteProfile()` falls back to the default first if it is in use;
  `renameProfile()` writes and moves in one shell command; `cycleProfile(±1)` wraps default → profiles.
- `profileButtons`: default first, then saved ones by name, at most `maxProfiles` (5); none while only the default
  exists. Tests: `tests/ui/profile*.body`.

## Presets and the welcome screen

What a person sees is in [docs/usage.md](../../docs/usage.md#the-first-start-choosing-a-preset).

- `app/presets/<name>.toml` + `lib/presets.js` (`LIST`: order, titles, texts; the first is the recommended one, what
  Esc on the first start applies). A new preset needs both; `tests/logic.test.mjs` fails if they disagree, if a preset
  skips a value, lacks `[layout]` or has an app in two tiles.
- First start = `Component.onCompleted` found no config text **and** `migrateLegacy()` found nothing →
  `welcomeFirstRun` + `welcomeOpen`. Nothing is written until a preset is chosen.
- `factoryReset()` (⚙ > Profiles > `menus/FactoryReset.qml`, two clicks): `cp -a` of the config folder to
  `<folder>.reset-<date>`, then removes `config.toml*` and `profiles/`, and resets settings, layout, profile in use
  (`stateDir/profile`) and usage in memory with `configLoaded = false` so nothing is saved, then opens the welcome
  screen as a first start (`welcomeFirstRun`). `super-key` and Hyprland's `bindings.lua` stay. `tests/ui/factory-reset.body`.
- One concept in the UI: **profile**. The presets are "ready-made profiles" (the code keeps the word preset).
  `applyPreset()`: on the first start (`welcomeFirstRun`) it is `applyConfigText()` + `saveNow()` into `config.toml`, and
  `presetsToSave()` fills free profile slots with the others (list order, so Clean is made last and is the one left out
  when the 5 slots run out); later it is `addPresetProfile()`: a NEW profile (`uniqueProfileName()`: `dock-2`), switched
  to, nothing replaced, refused when `profilesFull`. It used to replace the profile in use (with a `.bak`); users
  could not tell presets from profiles, hence the change.
- Profiles are listed in the order they were made: `stateDir/profile-order` (one name per line), written by
  `setProfiles()` at every create / rename / delete / preset; the lister reads it and appends unknown files
  alphabetically. Never assign `profileNames` directly (and never `.sort()` it): the chips, the strip buttons and Ctrl+P use it.
- `Welcome.qml` lives in `launcherWin`, centred, and replaces `card`/`dockedArea` (both hidden, their Loaders lose
  `focus`) so it fits whatever the mode. Keys go to `welcomeKey()`.
- A preset (or an import) replaces the tree with another shape: `Node` views of the old one still evaluate once, so
  `Tree.nodeAt()` returns `undefined` for a missing path and `ratioOf()` falls back to 0.5.

## Usage

`launchApp(entry)` is the **only** place that runs `entry.execute()` (`AppCell`, `launchSelected()`, `launchAllIn()`
call it); `noteLaunch(id)` counts into `usageData`, saved 1.5 s later. It orders `searchResults` (equal counts fall
back to the name). Tests: `tests/ui/usage*.body`.
