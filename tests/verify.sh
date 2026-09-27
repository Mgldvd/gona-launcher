#!/bin/sh
# Automated smoke checks for the Gona Launcher Omarchy plugin.
#
# As an overlay plugin this runs inside the shared, already-running omarchy-shell process (see
# CLAUDE.md), not as a standalone `qs -p` instance the way the old Cinnamon build did -- so there
# is no isolated-HOME instance to boot and drive with xdotool any more. This script only checks
# what can be checked without a live Wayland/omarchy-shell session: the plugin manifest, the pure-JS
# logic (app/lib/*.js: layout, keys, colors, toml, config, fx) and that the compiled effect shader
# is the one its source produces. Everything else -- opening/closing, focus,
# drag-and-drop, colours, the resize grip, pixel-level rendering -- is verified by hand against
# the real running shell (`omarchy-shell shell toggle gona.launcher`), watching its log for
# `ERROR|WARN|TypeError|ReferenceError`.
#
# Usage: tests/verify.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  OK  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL  $1 -- $2"; }

if command -v omarchy >/dev/null 2>&1; then
    if omarchy plugin validate "$ROOT" >/tmp/gona-launcher-validate.$$ 2>&1; then
        ok "manifest.json validates against the Omarchy plugin schema"
    else
        fail "manifest.json validates against the Omarchy plugin schema" "$(cat /tmp/gona-launcher-validate.$$)"
    fi
    rm -f /tmp/gona-launcher-validate.$$
else
    echo "SKIP  manifest validation -- 'omarchy' is not on PATH"
fi

if command -v node >/dev/null 2>&1; then
    if node --test "$ROOT/tests/logic.test.mjs" >/tmp/gona-launcher-logic.$$ 2>&1; then
        ok "layout.js / keys.js / colors.js / toml.js / config.js / fx.js unit tests"
    else
        fail "layout.js / keys.js / colors.js / toml.js / config.js / fx.js unit tests" "$(tail -20 /tmp/gona-launcher-logic.$$)"
    fi
    rm -f /tmp/gona-launcher-logic.$$
else
    echo "SKIP  logic unit tests -- 'node' is not on PATH"
fi

# every version has its section in CHANGELOG.md (what people read when they update), and the file has an Unreleased one
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/manifest.json")"
if [ -f "$ROOT/CHANGELOG.md" ] && grep -q "^## $VERSION\b" "$ROOT/CHANGELOG.md" && grep -q "^## Unreleased" "$ROOT/CHANGELOG.md"; then
    ok "CHANGELOG.md has a section for $VERSION and an Unreleased one"
else
    fail "CHANGELOG.md" "needs a '## $VERSION' section (manifest.json's version) and a '## Unreleased' one"
fi

# a file's text is never a command argument (every process can read /proc/<pid>/cmdline, and bindings.lua can hold
# tokens): the launcher writes files itself with writeFile()
if grep -n "printf '%s'" "$ROOT"/app/*.qml "$ROOT"/app/*/*.qml >/tmp/gona-launcher-argv.$$ 2>/dev/null; then
    fail "no file text passed to a shell as an argument" "$(cat /tmp/gona-launcher-argv.$$) (use writeFile())"
else
    ok "no file text passed to a shell as an argument"
fi
rm -f /tmp/gona-launcher-argv.$$

# the committed .qsb must be what tools/build-shaders.sh makes from the source (qsb output is deterministic)
if command -v qsb >/dev/null 2>&1 || [ -x /usr/lib/qt6/bin/qsb ]; then
    TMP="$(mktemp -d)"
    if OUT="$TMP" sh "$ROOT/tools/build-shaders.sh" >/dev/null 2>&1; then
        stale=""
        for f in "$TMP"/*.qsb; do cmp -s "$f" "$ROOT/app/shaders/$(basename "$f")" || stale="$stale $(basename "$f")"; done
        if [ -z "$stale" ]; then ok "app/shaders/*.qsb are up to date with their .frag source"
        else fail "app/shaders/*.qsb are up to date with their .frag source" "stale:$stale (run tools/build-shaders.sh)"; fi
    else
        fail "shaders compile" "tools/build-shaders.sh failed"
    fi
    rm -rf "$TMP"
else
    echo "SKIP  shader freshness -- 'qsb' is not installed (qt6-shadertools)"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
