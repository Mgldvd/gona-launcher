#!/usr/bin/env bash
#
# Scans git history for AI co-author / attribution trailers that slipped
# through before the hook was installed, or from a repo that doesn't have
# the hook (e.g. a clone that hasn't run install.sh).
#
# Usage: ./verify.sh [path-to-repo]   (defaults to current directory)

set -euo pipefail

REPO="${1:-.}"
cd "$REPO"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not a git repository: $REPO" >&2
  exit 1
fi

echo "Scanning $(git rev-parse --show-toplevel) for AI attribution trailers..."
echo ""

FOUND=0

check() {
  local label="$1"
  local pattern="$2"
  local hits
  hits="$(git log --all -i --grep="$pattern" -E --pretty=format:'%H %s' || true)"
  if [ -n "$hits" ]; then
    FOUND=1
    echo "== $label =="
    echo "$hits"
    echo ""
  fi
}

check "Co-Authored-By (any AI)" 'Co-Authored-By:.*(claude|copilot|cursor|codex|chatgpt|gpt-[0-9]|openai|anthropic|gemini|bard|ai assistant)'
check "Generated with ..."      'Generated (with|by)'
check "AI-Assisted / AI-Generated" '(AI-Assisted|AI-Generated):'
check "Created with [AI tool]"  'Created (with|by).*(claude|copilot|cursor|codex|chatgpt|openai|anthropic|gemini)'
check "claude.ai/code session links" 'claude\.ai/code'

if [ "$FOUND" -eq 0 ]; then
  echo "Clean. No AI attribution trailers found in history."
else
  echo "----"
  echo "Found contaminated commits above. To rewrite history and strip these"
  echo "trailers, see reference/clean-history.md in the commit-convention skill"
  echo "for the git-filter-repo procedure (git filter-branch is discouraged"
  echo "upstream in favor of filter-repo)."
  echo ""
  echo "WARNING: rewriting history changes commit hashes. Only do this on"
  echo "branches you can force-push safely, and coordinate with anyone else"
  echo "who has cloned the repo."
fi
