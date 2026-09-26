# CLAUDE.md

Gona Launcher: a highly configurable app launcher (apps in tiles laid out as a split tree) written in Quickshell 0.3.1 (QML) as an
**Omarchy shell plugin** (`overlay` + `bar-widget`, id `gona.launcher`). Checked on Omarchy 4.0, Qt 6.11, Hyprland 0.56.

## Rules

- The user writes Spanish; **every UI string is English**.
- `docs/` and `README.md` are for people; keep them in step with every change (settings → `docs/configuration.md`,
  effects → `docs/effects.md`, keys and menus → `docs/usage.md`).
- `.memory/` holds the working notes for changing the code. **Never duplicate** between `docs/` and `.memory/`: a fact
  lives in one place, the other links to it. New internals, traps and decisions go in `.memory/`.
- `app/Overlay.qml` is the only file with state; every other `.qml` is a view receiving it as `shell`. Pure logic lives
  in `app/lib/*.js` (`.pragma library`, never reads `shell`, tested with Node).
- The shell under test is the user's **live desktop session**: read its log after every sync, then run
  `omarchy restart shell` (hot reload keeps stale code; the user allowed it every time), never drive it with `wtype`/`ydotool` ([details](.memory/workflow/live-shell.md)).
- Add a UI test for every bug found by hand.
- **Every commit that changes `app/` or `manifest.json` carries its line under "Unreleased" in `CHANGELOG.md`** (a hook in
  `tools/hooks` checks it; `git config core.hooksPath tools/hooks`), and a release raises the version in `manifest.json`, dates that
  section, tags and publishes, so people can update with `omarchy plugin update` and read what changed
  ([how](docs/development.md#how-people-update-and-what-every-commit-owes-them)). Never rewrite `master`: updates only fast-forward.
- Never commit videos or large images: they go to the `media` GitHub Release
  ([how](docs/development.md#media-videos-and-large-images)).
- Work on `dev`. `master` is production only (what `omarchy plugin add` installs): never commit to it by hand, publish
  with `tools/release.sh`, and push only when the user asks ([why](.memory/decisions/0004-master-is-production.md)).

## Commands

```sh
tools/install.sh                                  # sync manifest.json + app/ to ~/.config/omarchy/plugins/gona.launcher (hot-reloads)
omarchy-shell shell toggle gona.launcher          # summon | hide; payload e.g. '{"tab":"keys"}'
journalctl --user _PID=$(pgrep -f "quickshell -n -p /usr/share/omarchy/shell") -n 40 --no-pager
tests/verify.sh                                   # manifest, Node unit tests (app/lib), shader up to date
tests/ui.sh [name ...]                            # QtTest in a throw-away instance; do not type while it runs
tools/build-shaders.sh                            # after editing app/shaders/fx.frag (commit the .qsb)
tools/release.sh                                  # dev -> master (production files only), no push
```

## Where to read before changing something

- Project docs: [docs/architecture.md](docs/architecture.md) (files, windows, saving, colours, menus, effects),
  [docs/development.md](docs/development.md) (install loop, tests, conventions), [docs/configuration.md](docs/configuration.md),
  [docs/usage.md](docs/usage.md), [docs/effects.md](docs/effects.md), [docs/TODO.md](docs/TODO.md) (what is open, and what is decided against or not done).
- Working notes: [.memory/index.md](.memory/index.md) — pick the file for the area (state, windows, colours, effects,
  menus, launcher, gotchas, UI tests, decisions).
- Official: [Quickshell 0.3.1 types](https://quickshell.org/docs/v0.3.1/types/) · [Omarchy manual](https://learn.omacom.io/2/the-omarchy-manual) ·
  [Hyprland wiki](https://wiki.hypr.land/) · [Qt QML](https://doc.qt.io/qt-6/qtqml-index.html) ·
  [Qt Quick](https://doc.qt.io/qt-6/qtquick-index.html) ·
  [wlr-layer-shell](https://wayland.app/protocols/wlr-layer-shell-unstable-v1).
- The Omarchy shell's own source (plugin API, how `open`/`close`/`toggle` are called): `/usr/share/omarchy/shell/`
  (read only). For `~/.config/hypr/*` or `omarchy …` commands, load the `omarchy` skill.
