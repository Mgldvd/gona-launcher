# Attribution patterns this skill removes

These are the trailer/line shapes the commit-msg hook (`scripts/commit-msg`)
strips, and that `scripts/verify.sh` scans history for. Case-insensitive.

| Pattern (regex, illustrative) | Matches things like |
|---|---|
| `^Co-Authored-By:.*` | `Co-Authored-By: Claude <noreply@anthropic.com>`, `Co-authored-by: GitHub Copilot <...>`, any tool name |
| `^Generated[ -]with.*` | `Generated with Claude Code`, `🤖 Generated with [Cursor]` |
| `^Created[ -](with\|by).*(claude\|copilot\|cursor\|codex\|...)` | `Created with Codex`, `Created by ChatGPT` |
| `^AI-Generated:.*`, `^AI-Assisted:.*` | explicit AI-disclosure trailers |
| `^Assisted-by:.*` | `Assisted-by: Copilot` |
| `^Co-Generated[ -]by.*` | variant phrasing some tools use |
| `^Signed-off-by:.*(claude\|copilot\|...)` | a bot/tool signing off instead of a human |
| `^\[claude-code\].*`, `^\[copilot\].*`, `^\[cursor\].*`, `^\[codex\].*` | bracket-tag prefixes some integrations add |
| `.*claude\.ai/code.*` | Claude Code session-link footers |

## Known per-tool defaults (as of this writing)

- **Claude Code**: adds `Co-Authored-By: Claude <noreply@anthropic.com>` and
  a `🤖 Generated with Claude Code` line, plus a session URL, to commits and
  PR descriptions it creates — controllable via the `attribution` settings
  key (see `SKILL.md`).
- **GitHub Copilot**: Copilot Chat/agent modes can be prompted to draft a
  commit message with an attribution line; there is no single documented
  global toggle equivalent to Claude Code's, so the project-instructions
  file (`.github/copilot-instructions.md`) plus the hook are the reliable
  controls.
- **Cursor**: has shipped a commit-message co-author toggle under different
  settings paths across versions; check the current Settings UI. `.cursorrules`
  plus the hook are the reliable controls regardless of what the toggle is
  named this release.
- **OpenAI Codex CLI / ChatGPT agents, Windsurf, Aider, Tabnine, Amazon Q,
  and anything else**: not all of these expose a setting at all. The
  commit-msg hook is the only mechanism guaranteed to catch every one of
  them, because it runs after any tool has written the message and before
  git accepts the commit — it doesn't depend on the tool cooperating.

This is why the skill treats the git hook as the source of truth and the
per-tool settings as a secondary "don't even try" nudge.
