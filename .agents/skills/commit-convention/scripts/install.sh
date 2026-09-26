#!/usr/bin/env bash
#
# Installs the commit-convention protections:
#   1. A global git commit-msg hook at ~/.git-hooks/commit-msg that strips
#      AI co-author/attribution trailers from every commit, in every repo,
#      regardless of which tool made the commit.
#   2. (Optional) a per-project hook at .git/hooks/commit-msg, for repos
#      that already set core.hooksPath to something else and so would not
#      pick up the global hook.
#   3. Claude Code's own setting to stop it from adding a trailer in the
#      first place (belt-and-suspenders; the hook is the real backstop).
#
# Usage:
#   ./install.sh            # install the global hook only
#   ./install.sh --project  # also install into the current repo's .git/hooks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/commit-msg"
GLOBAL_HOOKS_DIR="$HOME/.git-hooks"

echo "==> Installing global commit-msg hook to $GLOBAL_HOOKS_DIR"
mkdir -p "$GLOBAL_HOOKS_DIR"
cp "$HOOK_SRC" "$GLOBAL_HOOKS_DIR/commit-msg"
chmod +x "$GLOBAL_HOOKS_DIR/commit-msg"

CURRENT_HOOKS_PATH="$(git config --global core.hooksPath || true)"
if [ -n "$CURRENT_HOOKS_PATH" ] && [ "$CURRENT_HOOKS_PATH" != "$GLOBAL_HOOKS_DIR" ]; then
  echo "!! git config --global core.hooksPath is already set to: $CURRENT_HOOKS_PATH"
  echo "   Not overwriting it. Either move your existing hooks into $GLOBAL_HOOKS_DIR"
  echo "   (keeping commit-msg from this install), or manually add the filtering"
  echo "   logic from $HOOK_SRC to your existing commit-msg hook there."
else
  git config --global core.hooksPath "$GLOBAL_HOOKS_DIR"
  echo "==> git config --global core.hooksPath set to $GLOBAL_HOOKS_DIR"
fi

if [ "${1:-}" = "--project" ]; then
  if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_DIR="$(git rev-parse --git-dir)"
    PROJECT_HOOKS_DIR="$GIT_DIR/hooks"
    mkdir -p "$PROJECT_HOOKS_DIR"
    if [ -f "$PROJECT_HOOKS_DIR/commit-msg" ] && ! grep -q "commit-convention" "$PROJECT_HOOKS_DIR/commit-msg" 2>/dev/null; then
      echo "!! $PROJECT_HOOKS_DIR/commit-msg already exists and looks unrelated."
      echo "   Not overwriting. Merge $HOOK_SRC into it by hand, or chain it:"
      echo "     append: \"$GLOBAL_HOOKS_DIR/commit-msg \\\"\$1\\\"\" to the existing script."
    else
      cp "$HOOK_SRC" "$PROJECT_HOOKS_DIR/commit-msg"
      chmod +x "$PROJECT_HOOKS_DIR/commit-msg"
      echo "==> Installed project-local hook at $PROJECT_HOOKS_DIR/commit-msg"
    fi
  else
    echo "!! --project passed but current directory is not a git repo; skipped."
  fi
fi

echo "==> Configuring Claude Code to not add a co-author trailer"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
if command -v jq > /dev/null 2>&1; then
  if [ -f "$CLAUDE_SETTINGS" ]; then
    TMP_SETTINGS="$(mktemp)"
    jq '.attribution.commit = false | .attribution.pr = false' "$CLAUDE_SETTINGS" > "$TMP_SETTINGS" && mv "$TMP_SETTINGS" "$CLAUDE_SETTINGS"
  else
    echo '{"attribution": {"commit": false, "pr": false}}' | jq '.' > "$CLAUDE_SETTINGS"
  fi
  echo "==> Set attribution.commit: false and attribution.pr: false in $CLAUDE_SETTINGS"
else
  echo "!! jq not found. Manually add this to $CLAUDE_SETTINGS:"
  echo '   { "attribution": { "commit": false, "pr": false } }'
fi

echo ""
echo "Done. New commits (from Claude Code, Copilot, Cursor, Codex, or any other"
echo "tool) will have AI co-author/attribution trailers stripped automatically"
echo "by the commit-msg hook, regardless of what any tool's own settings do."
