# 0004 — master is production, dev is where work happens (2026-09-24)

**Problem**: `omarchy plugin add` clones the repository's default branch whole into
`~/.config/omarchy/plugins/gona.launcher/`, so every install carried the docs, the 9 MB promo video, tests, tools and
assistant skills, none of which the plugin uses.

**Decision** (the user's): `master` holds only production — `manifest.json`, `app/`, `LICENSE*`, `preview.png` (the
marketplace picture), a short README generated from `tools/release/README.md`, and — added later, because GitHub reads
them from the default branch — `CONTRIBUTING.md` and `.github/ISSUE_TEMPLATE/`. Everything else lives on `dev` (the CI
workflow, `.github/workflows/verify.yml`, runs on `dev` pushes).
`tools/release.sh` copies the production files from a clean, verified `dev` to `master` and commits; it never pushes.

**Consequences**: never commit on `master` by hand, and never merge `dev` into it (that would bring every file back);
only `tools/release.sh`. Pushing `master` is what ships to users (`omarchy plugin update`); the user has allowed pushing `dev` and `master` when a
change is finished and tested.
On 2026-09-26, at 1.0.0, the history of both branches was reset to one `init` commit each (a force push; the old
Cinnamon-era branch was deleted), so a clone downloads only production files from `master`. A backup bundle of the old history
was kept outside the repository. How to
release, for people: [docs/development.md](../../docs/development.md#branches-and-releases).
