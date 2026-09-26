#!/bin/sh
# Prints the CHANGELOG.md section of a version (default: manifest.json's) as the notes of its GitHub release:
#   gh release create v1.0.1 --title "Gona Launcher 1.0.1" --notes-file <(tools/release-notes.sh)
# Usage: tools/release-notes.sh [version]
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/manifest.json")}"
awk -v v="$VERSION" '
    /^## / { on = ($2 == v); next }
    on { print }
' "$ROOT/CHANGELOG.md" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
printf '\n**Update:** `omarchy plugin update gona.launcher` (then `omarchy restart shell` if the launcher looks unchanged). New here: `omarchy plugin add https://github.com/Mgldvd/gona-launcher.git --enable`.\n'
