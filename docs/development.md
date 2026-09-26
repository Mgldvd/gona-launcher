# Development

## Environment

Checked on Omarchy 4.0 (`omarchy-shell` with shell plugins, `omarchy plugin …`), Quickshell 0.3.1, Qt 6.11, Hyprland
0.56 on Arch. There is no build step and no linter, except the effect shader: `app/shaders/fx.frag` is compiled to a
committed `.qsb` (see Tests below).

## Install and iterate

The shell loads plugins from `~/.config/omarchy/plugins/<id>/` and refuses symlinks there, so the plugin is a
copy:

```sh
tools/install.sh    # validates the manifest, then copies manifest.json and app/ (nothing else) to the plugin folder
```

The running shell picks the change up on its own (`Local plugin changed, reloading` in its log), but the reload
can be slow or serve a stale compile: if a change does not show, `omarchy restart shell` (it flashes the bar and
every panel). The first install also needs `omarchy-shell shell rescanPlugins` and
`omarchy plugin enable gona.launcher`.

Open it with `omarchy-shell shell toggle gona.launcher`, or straight to a tab:
`omarchy-shell shell summon gona.launcher '{"tab":"colors"}'`. The plugin runs in your own desktop session; its
log is `journalctl --user _PID=<pid of quickshell -n -p /usr/share/omarchy/shell>`.

## Branches and releases

Work happens on `dev`, which holds everything: the plugin, docs, tests, tools, `.memory/`. `master` is production and
is what `omarchy plugin add` clones: only `manifest.json`, `app/`, the license files, `preview.png`, a short README
(written from `tools/release/README.md`), `CONTRIBUTING.md` and `.github/ISSUE_TEMPLATE/` (GitHub reads those from the default
branch). The workflow `.github/workflows/verify.yml` runs `tests/verify.sh` (only what needs node) on every push to `dev`. A release
is also tagged (`git tag -a vX.Y.Z <master commit>`, `gh release create vX.Y.Z --notes-file ...`) with the notes of
[CHANGELOG.md](CHANGELOG.md). Never commit to `master` by hand; publish with

```sh
tools/release.sh          # on a clean dev: runs tests/verify.sh, copies the production files to master, commits there
git push origin master    # when you mean it (users get it with omarchy plugin update)
```

## Tests

- `tools/build-shaders.sh`: compiles `app/shaders/fx.frag` to the `fx.frag.qsb` the launcher loads (needs `qsb`, package
  qt6-shadertools). Run it after editing the shader and commit both.
- `tests/verify.sh`: validates the manifest, runs `node --test tests/logic.test.mjs` (layout, keys, colours, TOML,
  config, effects) and checks that `app/shaders/fx.frag.qsb` is what `tools/build-shaders.sh` makes from its source. No
  Quickshell needed.
- `tests/ui.sh [name ...]`: real key and mouse events (QtTest) against a throw-away copy of the plugin in its own
  Quickshell instance with its own `HOME`, so your configuration and the live shell are untouched. It needs the
  running Wayland session; for a few seconds per test transparent full-screen surfaces exist and the launcher takes
  the keyboard, so do not type or click while it runs. `tests/ui/run.py` documents the format of a test (a body of
  JS run inside a `TestCase` injected into a copy of `app/Overlay.qml` or `app/menus/OptionsMenu.qml`, with directives for the
  window mode, fixtures, an Omarchy theme and so on). Add a test for every bug found by hand. The whole suite takes
  several minutes (`effects` plays every effect in every position); run a few by name while working.

### Seeing an effect frame by frame

Effects are fast; to look at one, freeze it in a UI test: `fx.t = 0.4` (this breaks its binding), `fx.snap()`, wait,
then `Quickshell.execDetached(["grim", path])` and read the PNG. `grabToImage` never calls back on a layer-shell window
here. Take frames at several `t` and in several modes (`// edge:` directives).

## The promo video

`promo.mp4` and `promo.webp` (the README cover and its Video section) are recorded from the real launcher, not mocked
up. They are not in the repository; see [Media](#media-videos-and-large-images) for where they live and how to replace
them.
`tools/promo/director.body` is a script for the same throw-away instance the UI tests use (real key and mouse events, its own
`HOME`, a curated configuration written by `tools/promo/demo-config.mjs` through the launcher's own `app/lib/toml.js`/`config.js`);
`PromoBackdrop.qml` (backdrop, glows, a mock bar with the launcher's button) and `PromoOverlay.qml` (title cards,
captions, a pointer, since the capture has none) are the stage. Launching apps and the power buttons are switched off in
the copy, so a demo can never run or shut down anything.

```sh
tools/promo/record.py     # ~1 minute: takes over the screen and records it with gpu-screen-recorder (-> tools/promo/out/raw.mp4)
tools/promo/edit.sh       # trims, fades and writes tools/promo/out/promo.mp4 (60 fps) and promo.webp (24 fps, 960 px)
gh release upload media tools/promo/out/promo.mp4 tools/promo/out/promo.webp --clobber   # keeps the originals
```

The README screenshots (`docs/media/screenshots/`, 1366x686: a 1366x768 screen without its bottom strip, where the
video has its captions) are frames of that video, cut with
`ffmpeg -ss <second> -i promo.mp4 -frames:v 1 f.png && magick f.png -crop 1366x686+0+0 +repage -strip NN-name.png`,
plus live shots of what the video does not show (the ⚙ menu; `13-welcome.png` is the presets scene):

```sh
tools/promo/stills.py     # ~15 s on the same stage: one full-screen PNG per ⚙ tab in tools/promo/out/stills
magick tools/promo/out/stills/menu-colors.png -resize '1366x768!' -crop 1366x686+0+0 +repage -strip docs/media/screenshots/12-settings.png
```

`preview.png` (the marketplace picture, in git) is the Omarchy ready-made profile on the same stage, opened with the classic effect and cut
from a full-screen `grim` of the stage's monitor (`applyConfigText(presetText("omarchy"))` in a director body, then `grim -o`).
The stage, the recording and the launcher all use the monitor Hyprland has focused (`stage.focused_monitor()`, passed to the
windows as `GONA_SCREEN`), so a second monitor cannot pull the launcher away from what is being recorded.
`record.py` and `stills.py` build the stage with `tools/promo/stage.py`. Both READMEs list the screenshots: `README.md`,
and `tools/release/README.md` (master's), which links them on the `dev` branch since master does not carry them.

Do not type or click while it records. The stage windows are layer-shell surfaces, and those stack in the order they
were mapped, so the director re-maps the words above the launcher each time it opens (`raise()`). Timings are for a
1366x768 screen; the app icons are those of the machine it runs on, so the video shows that machine's apps. Needs
`gpu-screen-recorder`, `ffmpeg` (with libwebp) and `node`; the WebP takes a few minutes to encode.

## Media: videos and large images

Git keeps every version of every file forever, so a video committed once, even if deleted later, stays in `.git` and
in every clone. The repository was purged of 70 MB of old promo videos for this reason. **Videos and large images are
never committed**: they live as assets of the `media` GitHub Release, whose files can be replaced as often as needed
without the repository growing. Only small pictures the docs show stay in git (`docs/media/screenshots/`, a few hundred
KB each at most, and `preview.png`).

```sh
gh release view media                                  # what it holds
gh release upload media file.mp4 --clobber             # add a file, or replace one of the same name (same URL)
gh release delete-asset media file.mp4                 # remove one
gh release edit media --notes "..."                    # change its description
```

Each file is at `https://github.com/Mgldvd/gona-launcher/releases/download/media/<name>`. Replacing a file keeps its
URL; GitHub and browsers may show the old one for a few minutes. Do not create one release per video: add to `media`.
A file generated locally goes in an ignored folder such as `tools/promo/out/` until it is uploaded.

### What the README shows

GitHub plays a video inside a README only when it was uploaded through its web page (a `user-attachments` link); it
strips `<video>` tags and does not play a video linked from anywhere else, the `media` release included. Release links
also do not display while the repository is private. So the README uses attachment links, and the `media` release keeps
the originals:

- The cover at the top is `promo.webp` as an `<img>`: an animation that plays by itself, without sound.
- The **Video** section is `promo.mp4`: its link alone on a line becomes a player with controls.

To replace them (there is no command line or API for attachments):

1. Open a new issue on GitHub (it does not need to be saved) and drag the new `promo.webp` and `promo.mp4` into its
   text box; each becomes a `https://github.com/user-attachments/assets/...` link (up to 10 MB each on a free account).
2. Put the WebP link in the cover's `<img src>` and the MP4 link alone on its line under `## Video`, in both
   `README.md` and `tools/release/README.md` (master's), then `tools/release.sh`; close the issue without creating it.
3. Upload the same files to the `media` release with `--clobber`, so the originals stay together.

Attachments are stored by GitHub outside git, so they do not make the repository grow; in a private repository only
people with access see them.

## Conventions

- Every UI string is English.
- Match the surrounding code's density of comments, naming and idiom. Design notes per area, the traps found so far
  and the decisions behind them are in [`.memory/`](../.memory/index.md).
- Commits follow the repository's commit standard (`.claude/skills/commit-convention`).
- QML gotchas: do not name a type `ColorGroup`; the overlay window must stay `color: "transparent"`; a `Loader`
  is a focus scope; a `FileView` blocks until loaded only for its first path (read arbitrary files with
  `readFile()`); do not call `Qt.quit()` from a QtTest handler; inline `component` types make hot reload stale.
