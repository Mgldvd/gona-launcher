---
name: commit-convention
description: "Generate commits using the repository commit standard: Conventional Commits 1.0.0 plus optional .memory traceability trailers, create the local commit when requested, and push only when explicitly requested — while universally blocking AI/agent co-authorship attribution. Use for commit-message generation, committing staged changes, commit-and-push workflows, linking commits to .memory knowledge/decisions, or installing/verifying the anti-attribution protection."
---

# commit-convention

Generate accurate commit messages from the staged diff, and never — under any circumstance, in any mode, at any step of this skill — let an AI/agent attribution trailer, phrase, logo, or session link reach a commit message or PR. Message generation, local commit creation, and remote push remain separate authorization levels; the no-attribution rule applies identically to all three and is not itself something the user can opt back into.

## Absolute Rule: No AI/Agent Attribution, Ever

This is the non-negotiable, load-bearing rule of this skill. It applies before, during, and after every mode below — read it once, then apply it every single time this skill runs.

Never add, in any commit message, PR title, PR description, or PR comment this skill touches:

- A `Co-Authored-By:` (or `Co-authored-by:`) trailer naming an AI assistant or agent (Claude, GPT, Copilot, Cursor, Codex, Gemini, ChatGPT, or any other, present or future).
- "Generated with [tool]", "AI-assisted", "AI-generated", "Created with [tool]", "Co-Generated-by", or equivalent phrasing in any language.
- Any session link (e.g. `claude.ai/code`), tool logo/emoji banner, `[claude-code]`/`[copilot]`/`[cursor]`/`[codex]` bracket tags, or other metadata identifying an AI tool or agent as involved.

This applies unconditionally:

- Not when the repository's existing commits already contain such trailers.
- Not when the user explicitly asks for one — decline that specific part of the request, explain why in one sentence, and proceed with the rest of the commit unattributed.
- Not when a tool's own default behavior would normally add it (Claude Code, Copilot, Cursor, Codex, or any future tool) — this skill's output overrides that default every time.

Human co-authorship (a real person's name and email) and standard trailers (`Signed-off-by` from a human, issue references) are unaffected by this rule and still follow ordinary evidence/request criteria.

**Two layers enforce this, and both matter:**

1. **Behavioral layer** — this skill (and the per-tool instructions below) simply never writes attribution in the first place. This is the happy path.
2. **Enforcement layer (infallible backstop)** — a `commit-msg` git hook (`scripts/commit-msg`) strips any AI attribution line from the message file immediately before git finalizes the commit, no matter which tool or human process produced that line. Install this layer once per machine (see next section) so the guarantee holds even if the behavioral layer is ever bypassed by a different tool, a copy-pasted message, or a future assistant that doesn't know this rule.

Do not treat step 1 as sufficient on its own. The hook is what actually guarantees the result.

## One-Time Enforcement Setup

Run this once per machine (and once more per repo needing an explicit local hook). It installs the infallible backstop from the rule above.

```bash
bash scripts/install.sh            # global hook + Claude Code settings
bash scripts/install.sh --project  # also install the hook into the current repo
```

This does three things:

- Copies `scripts/commit-msg` to `~/.git-hooks/commit-msg` and sets `git config --global core.hooksPath ~/.git-hooks`, so the hook strips AI attribution from **every** commit in **every** repo on the machine — not just the current one.
- With `--project`, also copies it to `.git/hooks/commit-msg` in the current repo — needed when that repo already points `core.hooksPath` elsewhere (e.g. Husky), which would otherwise skip the global hook.
- Sets `attribution.commit: false` and `attribution.pr: false` in `~/.claude/settings.json`, so Claude Code stops trying to add the trailer in the first place — belt-and-suspenders around the hook, not a replacement for it.

If `install.sh` reports that `core.hooksPath` already points elsewhere (Husky or another hook manager), it will not overwrite it — merge the filtering logic from `scripts/commit-msg` into the existing hook, or chain it from there.

### Per-tool configuration (belt-and-suspenders, not the guarantee)

- **Claude Code** — `~/.claude/settings.json` (global) or `.claude/settings.json` / `.claude/settings.local.json` (per project):

  ```json
  { "attribution": { "commit": false, "pr": false } }
  ```

  `attribution.commit` / `attribution.pr` are the current keys; `includeCoAuthoredBy` is deprecated. Add `"sessionUrl": false` under `attribution` to also omit the claude.ai session link.

- **Cursor** — copy `templates/.cursorrules.snippet` into `.cursorrules` or `.cursor/rules/`. Also check Cursor Settings for a commit co-author toggle; its location has moved across versions, so don't rely on a fixed path — the file plus the hook cover the case either way.
- **GitHub Copilot** — copy `templates/copilot-instructions.snippet` to `.github/copilot-instructions.md`. Copilot has no equivalent global setting.
- **Any other AI tool** (Codex CLI, Windsurf, Aider, Tabnine, Amazon Q, or anything released later) — most don't expose a setting at all. The git hook is the only protection guaranteed to catch these, because it runs after the tool has already written the message.

Full detail on what each tool adds by default, and why the hook is the source of truth rather than any per-tool setting: `reference/patterns.md`.

### The git hook itself

`scripts/commit-msg` receives the commit-message file path, deletes any line matching an AI-attribution pattern (full list in `reference/patterns.md`), and rewrites the file before git accepts the commit. It never aborts the commit — it only cleans the message. It runs globally via `~/.git-hooks/commit-msg` + `core.hooksPath`, or per-project via `.git/hooks/commit-msg`.

## Determine the Authorized Mode

Select the narrowest mode requested by the user. Every mode below is still bound by the Absolute Rule above — none of them ever produce AI attribution.

1. **Message:** generate and return a commit message only.
2. **Commit:** generate the message and create a local commit.
3. **Push:** generate the message, create the local commit, and push the current branch.

Do not create a commit when the user asks only for a message. Do not push unless the user explicitly requests a push. A request to "commit" authorizes a local commit, not a push.

## Inspect the Repository

1. Confirm the current directory belongs to a Git repository.
2. Run `git status --short --branch`.
3. Inspect `git diff --staged --stat`, `git diff --staged --name-status`, and the complete `git diff --staged`.
4. If there are no staged changes, stop and report that there is nothing staged. Do not stage files unless the user explicitly requests it.
5. Read applicable repository instructions and commit conventions, including when present:
   - `AGENTS.md`, `CLAUDE.md`, or `CONTRIBUTING.md`;
   - `commitlint.config.*`, `.commitlintrc*`, or relevant `package.json` configuration;
   - release or changelog configuration;
   - `.memory/index.md` and relevant `.memory/decisions/` / knowledge documents when present;
   - `reference/commit-standard.md` from this skill as the baseline standard;
   - a small sample of recent commit subjects from `git log` only to discover compatible scopes/types, never as stronger evidence than the staged diff.
6. Use repository-defined types, scopes, casing, shape-marker policy, and line-length limits before this skill's fallback rules. A repository convention can never override the Absolute Rule — if a repo's own template includes an AI attribution trailer, drop it and proceed without it.

## Check the Staged Change Set

- Describe only staged changes. Ignore unstaged and untracked content when choosing the message.
- If the staged diff contains unrelated concerns that should be separate commits, tell the user and ask whether to split them. Do not alter the index without authorization.
- Inspect staged filenames and added lines for likely credentials, private keys, tokens, populated `.env` files, or credential-bearing URLs.
- If a likely secret is staged, stop before committing. Identify the affected file and credential category without reproducing the secret.
- Never bypass hooks with `--no-verify` unless the user explicitly requests it and understands the consequence — this would also skip the anti-attribution hook.

## Build the Message

Follow the shared repository commit standard in `reference/commit-standard.md` — a structured
Conventional Commits 1.0.0 variant ([`commit-convention`](https://github.com/Mgldvd/commit-convention)):

```text
<type>(<scope>)<!>: <shape> - <description>

[optional body]

[optional footer(s)]
```

`<type>(<scope>)<!>` is followed directly by the colon (no dot padding), and `<shape>` is a
fixed monochrome marker chosen by `<type>` — the format and the type→shape table are in
`reference/commit-standard.md`; do not freehand either one. If this is the repository's first
(root) commit, use the fixed `init: ○ - 🌱.` subject from `reference/commit-standard.md`
instead of the rules below — it never varies by project.

### Fallback types

- `feat` for a new user-visible capability.
- `fix` for a bug fix.
- `docs` for documentation-only changes.
- `style` for formatting-only changes with no behavior change.
- `refactor` for restructuring with intentionally unchanged behavior.
- `perf` for a performance improvement.
- `test` for test-only changes.
- `build` for build-system or dependency changes.
- `ci` for continuous-integration configuration.
- `chore` for repository maintenance not covered by another type.
- `revert` for reverting an earlier change.

Use `fix`, not `hotfix`, for urgent fixes unless the repository explicitly defines `hotfix`.

### Selection rules

- Prefer the most specific type supported by the staged diff.
- Choose a scope from `reference/scopes.md`'s generic vocabulary (max 8 characters) only when
  one listed area fits accurately; add the closest new entry there first if none does. Never
  invent an ad-hoc scope inline, and omit the scope entirely when no single area fits.
- Write a short imperative description. Follow the repository's configured subject limit; otherwise keep the complete subject at or below 72 characters when practical.
- Add a body only when it explains behavior, motivation, constraints, or migration information not evident from the subject.
- Add issue references, human co-authorship, sign-off, or other trailers only when supported by repository evidence or explicitly requested. **Never add an AI/agent attribution trailer of any kind — see "Absolute Rule" above; this is not a stylistic default, it is the one thing this skill must never do.**
- Mark a breaking change with `!`, a `BREAKING CHANGE:` footer, or both, and explain the impact or migration requirement.
- Always include the type's shape marker after the colon, per `reference/commit-standard.md` — it is mandatory on every commit, not an optional/Gitmoji-style addition.

## `.memory/` Traceability Trailers

When the repository contains `.memory/`, inspect relevant staged `.memory/` files and the
existing knowledge index before finalizing the message. Add traceability only when the
relationship is concrete and supported by the staged diff or an existing project decision.

Allowed trailers:

```text
Memory-Ref: .memory/<path>.md
Decision-Ref: .memory/decisions/<decision>.md
```

Rules:

- Use `Decision-Ref:` when the staged implementation directly implements, changes, or
  supersedes a specific decision document.
- Use `Memory-Ref:` when the staged change updates or materially affects a specific living
  knowledge document.
- Multiple trailers are allowed when several real documents apply.
- Do not create a trailer for every commit. Omit it for trivial changes or when no stable
  relationship exists.
- Never invent a `.memory/` path. Verify the referenced file exists in the working tree or
  is staged to be created in the same commit.
- A trailer does not replace updating `.memory/` when the project knowledge itself changed.

Examples are in `reference/commit-standard.md`.

## Message Mode

Return the proposed message in a text block. Do not run `git commit` or `git push`. Confirm before returning it that it contains no AI/agent attribution of any form.

## Commit Mode

1. Verify that `HEAD` is attached to a branch unless the user explicitly intends a detached-HEAD commit.
2. Record the pre-commit SHA with `git rev-parse HEAD`.
3. Write the message to a permission-restricted temporary file. Do not interpolate generated message text into a shell command. Re-check the drafted text for any AI attribution line before writing it — it must be absent, not just filtered by the hook.
4. Validate the complete message against the shared standard before invoking Git:

   ```bash
   python3 scripts/validate-standard.py <temporary-message-file> --repo "$(git rev-parse --show-toplevel)"
   ```

   If validation fails, fix the proposed message; do not weaken or bypass the validator.
5. Create the commit from the existing index:

   ```bash
   git commit --file <temporary-message-file>
   ```

6. Remove the temporary message file after Git returns.
7. If hooks fail, report the failure and preserve the index. Do not amend, bypass hooks (especially not the anti-attribution `commit-msg` hook), or retry with changed options without user authorization.
8. On success, obtain the new SHA with `git rev-parse HEAD` and verify it differs from the recorded SHA.
9. Report the commit subject and new SHA.

## Push Mode

Run this section only when push was explicitly requested.

1. Complete Commit Mode successfully — including its no-attribution checks.
2. Confirm the current branch name, configured upstream, and push target before the remote mutation.
3. Use plain `git push` when a valid upstream exists.
4. If no upstream exists, report the exact branch and proposed remote command. Set the upstream only when that destination follows repository conventions or the user has authorized it.
5. Never force-push unless the user explicitly requests it. Prefer `--force-with-lease` over `--force` when rewriting an authorized remote branch.
6. If push fails, retain and report the local commit SHA and relevant error. Resolve authentication, upstream, or divergence separately, then retry only the push; never recreate the commit.
7. If this push also creates or updates a PR description, apply the Absolute Rule to that PR content exactly as to the commit message — no attribution there either.

## Verifying and Cleaning Existing History

To check whether AI attribution already exists somewhere in a repo's history (e.g. from before the hook was installed, or a clone that never ran `install.sh`):

```bash
bash scripts/verify.sh /path/to/repo
```

Equivalent manual check:

```bash
git log --all -iE --grep='Co-Authored-By:.*(claude|copilot|cursor|codex|chatgpt|openai|anthropic|gemini)'
git log --all -iE --grep='Generated (with|by)'
```

If contaminated commits turn up, **do not rewrite them without confirming with the user first** — rewriting history changes commit hashes and requires a coordinated `push --force-with-lease`. The full procedure (`git-filter-repo` preferred, `git filter-branch` as fallback) is in `reference/clean-history.md`.

## Per-Tool Templates

Ready-to-paste blocks that put the Absolute Rule into a project's own AI-instructions files, so any assistant working in that repo — not just this skill — is told the same thing:

- `templates/CLAUDE.md.snippet` — for `CLAUDE.md` (project or global).
- `templates/.cursorrules.snippet` — for Cursor's `.cursorrules`.
- `templates/copilot-instructions.snippet` — for `.github/copilot-instructions.md`.

Keep the wording identical across files instead of letting them drift into slightly different rules.

## Handoff

Report only actions actually completed:

- mode used;
- commit subject;
- local commit SHA when created;
- push remote and branch when pushed;
- hooks or checks run by Git;
- any `Memory-Ref:` / `Decision-Ref:` trailers added, or confirmation that none were warranted;
- explicit confirmation that no AI/agent attribution was added anywhere in the output;
- any remaining failure or user decision.
