# Contributing to Gona Launcher

Thanks for looking. The plugin is small QML plus a few pure JavaScript files; changes are easy to try on a real Omarchy desktop.

## Where things are

- `master` is what `omarchy plugin add` installs. Do not send changes to it: work on `dev`.
- `dev` has everything: the plugin (`app/`), the docs (`docs/`), the tests (`tests/`) and the tools (`tools/`).
- How it is built, and why: [docs/architecture.md](docs/architecture.md) and, for the traps, [.memory/index.md](.memory/index.md).

## Try a change

```sh
git clone -b dev https://github.com/Mgldvd/gona-launcher.git && cd gona-launcher
tools/install.sh                    # copies the plugin to ~/.config/omarchy/plugins/gona.launcher
omarchy restart shell               # the hot reload can keep old code: restart to be sure
omarchy-shell shell toggle gona.launcher
```

Read the shell's log after every install (the command is in [CLAUDE.md](CLAUDE.md)) and look for `TypeError`, `ReferenceError` and `WARN` near your change.

## Checks

```sh
tests/verify.sh    # the manifest, the unit tests of app/lib/*.js and the shader; needs only node
tests/ui.sh        # the UI tests, in a throw-away instance: it needs a Wayland session, and do not type while it runs
```

- A bug found by hand gets a test in `tests/ui/` (see [.memory/workflow/ui-tests.md](.memory/workflow/ui-tests.md)).
- Every UI string is English. `docs/` and the README change with the code (settings in `docs/configuration.md`, keys and menus in `docs/usage.md`).
- Commit messages follow Conventional Commits with the project's symbols, like the recent history (`feat(ui): ▲ - ...`, `fix(...)`, `docs: □ - ...`).

## Reporting a problem

Open an issue with what you did, what you expected, your Omarchy version and the shell's log. A screenshot helps.
