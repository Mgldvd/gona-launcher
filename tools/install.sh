#!/bin/sh
# Copies the plugin (manifest.json and app/) into the folder the Omarchy shell loads it from, validating it first.
# The shell refuses symlinks in that folder, so it has to be a real copy; it reloads the plugin by itself when the
# files change. The very first time also run `omarchy-shell shell rescanPlugins` and `omarchy plugin enable gona.launcher`.
# Usage: tools/install.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.config/omarchy/plugins/gona.launcher"
omarchy plugin validate "$ROOT" || exit 1
mkdir -p "$DEST"
rsync -a --delete --delete-excluded --include=/manifest.json --include='/app/***' --exclude='*' "$ROOT/" "$DEST/" || exit 1
omarchy plugin validate "$DEST"
