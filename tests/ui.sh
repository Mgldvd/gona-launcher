#!/bin/sh
# Interface tests: real key and mouse events against a throw-away copy of the plugin (see ui/run.py).
# Needs the running Wayland session; do not type or click while it runs (a few seconds per test).
# Usage: tests/ui.sh [test-name ...]
exec python3 "$(dirname "$0")/ui/run.py" "$@"
