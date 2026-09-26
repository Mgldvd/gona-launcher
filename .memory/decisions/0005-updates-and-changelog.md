# 0005 — People update with `omarchy plugin update`: changelog with every commit, `master` never rewritten (2026-09-26)

**Problem**: the plugin's users get changes through `omarchy plugin update <id>`, which (`/usr/share/omarchy/bin/omarchy-plugin-update`)
fetches the repository's HEAD, shows `git diff HEAD FETCH_HEAD`, asks, and then only `merge --ff-only`s. It knows nothing about
versions: what tells a person what changed is what is in that diff (a root `CHANGELOG.md`) and the version in `manifest.json`
(the bar button's right-click menu shows it).

**Decision** (the user's): every commit that changes `app/` or `manifest.json` carries its own line under `## Unreleased` in
`CHANGELOG.md`, and a release turns that into a dated section, raises the version and tags it. `tools/hooks/pre-commit` (turn on with
`git config core.hooksPath tools/hooks`) enforces the line, `tests/verify.sh` the section of the current version, and
`tools/release.sh` refuses a release without it or with `app/` changed since the version's tag. `CHANGELOG.md` travels to `master`.

**Consequences**: `master`'s history must never be rewritten or force-pushed again (it was reset once, at 1.0.0, before anyone had
installed it): a rewritten history is not a fast-forward and every installed copy would fail to update. Releases: `docs/development.md`
("How people update"). The marketplace listing (issue omacom/omarchy-plugin-marketplace#8851) is updated with its Plugin
verification form.
