#!/bin/sh
# Publishes the plugin from `dev` to `master`. `master` is production: it holds only what `omarchy plugin add` needs to
# install and run the plugin (manifest.json, app/), the license files, the marketplace picture (preview.png), a short
# README (kept here as tools/release/README.md), the CHANGELOG.md (what `omarchy plugin update` shows people), and what GitHub reads
# from the default branch: CONTRIBUTING.md and .github/ISSUE_TEMPLATE/. Everything else (docs, tests, tools, .memory, CLAUDE.md) lives on `dev`
# only. It commits on master (always a fast-forward: `omarchy plugin update` only fast-forwards, so master's history is never
# rewritten), tags the version and comes back to dev; it never pushes.
# It refuses when CHANGELOG.md has no section for manifest.json's version, or when app/ or manifest.json changed since that
# version was tagged (raise the version and add its section: docs/development.md).
# Usage: tools/release.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[ "$(git branch --show-current)" = dev ] || { echo "release.sh: run it from the dev branch" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "release.sh: commit or stash your changes first" >&2; exit 1; }
tests/verify.sh >/dev/null || { echo "release.sh: tests/verify.sh failed" >&2; exit 1; }
SHA="$(git rev-parse --short HEAD)"
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' manifest.json)"
grep -q "^## $VERSION\b" CHANGELOG.md || { echo "release.sh: CHANGELOG.md has no '## $VERSION' section (move \"Unreleased\" there and date it)" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && ! git diff --quiet "v$VERSION" dev -- app manifest.json; then
    echo "release.sh: app/ or manifest.json changed since v$VERSION was tagged: raise \"version\" in manifest.json and add its section to CHANGELOG.md" >&2
    echo "            (people update by version and by what CHANGELOG.md says; ALLOW_RETAG=1 only before anybody has v$VERSION)" >&2
    [ -n "$ALLOW_RETAG" ] || exit 1
fi

git switch -q master
# forced: a file dev tracks can reappear untracked on master (an editor or assistant rewriting one it has open)
# and would block the way back; dev has its own copy
trap 'git switch -q -f dev' EXIT
git rm -rq --ignore-unmatch app .github/ISSUE_TEMPLATE                                # files removed on dev go away here too
git checkout dev -- manifest.json app LICENSE LICENSE-MIT LICENSE-APACHE preview.png CONTRIBUTING.md CHANGELOG.md .github/ISSUE_TEMPLATE
git show dev:tools/release/README.md > README.md
git add -A manifest.json app LICENSE LICENSE-MIT LICENSE-APACHE preview.png README.md CONTRIBUTING.md CHANGELOG.md .github/ISSUE_TEMPLATE
# anything else on master is not production: drop it
for f in $(git ls-files); do
    case "$f" in manifest.json|app/*|LICENSE|LICENSE-MIT|LICENSE-APACHE|preview.png|README.md|CONTRIBUTING.md|CHANGELOG.md|.github/ISSUE_TEMPLATE/*) ;; *) git rm -q "$f" ;; esac
done
omarchy plugin validate "$ROOT" >/dev/null
if git diff --cached --quiet; then
    echo "release.sh: master already matches dev $SHA"
else
    git commit -q -m "chore(release): ○ - release $VERSION from dev $SHA"
    echo "release.sh: master now has dev $SHA ($VERSION); push it with: git push origin master"
fi
if ! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    git tag -a "v$VERSION" master -m "Gona Launcher $VERSION"
    echo "release.sh: tagged v$VERSION on master; publish it with:"
    echo "  git push origin dev master v$VERSION"
    echo "  gh release create v$VERSION --title \"Gona Launcher $VERSION\" --notes-file <(tools/release-notes.sh) --latest"
    echo "  (and, once it is listed, the marketplace's Plugin verification issue form: docs/development.md)"
fi
