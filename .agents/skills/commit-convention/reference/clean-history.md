# Cleaning AI attribution out of existing git history

Use this only after `scripts/verify.sh` has found contaminated commits. This
rewrites commit hashes on every commit after the point of change — treat it
as a destructive operation.

## Before you start

- Confirm with the user before running anything below. This is a
  history-rewrite; it is not reversible without a pre-rewrite backup, and it
  forces a `push --force` that can clobber collaborators' clones.
- Make a backup: `git branch backup-before-attribution-cleanup`
- If anyone else has cloned this repo, tell them to re-clone or hard-reset
  onto the new history after you push — their old clones will diverge.

## Preferred: git-filter-repo

`git filter-branch` is deprecated upstream in favor of
[`git-filter-repo`](https://github.com/newren/git-filter-repo). Install it
first (`pip install git-filter-repo`, or via your package manager).

`git-filter-repo` can rewrite commit messages with a callback:

```bash
git filter-repo --message-callback '
import re

patterns = [
    rb"(?im)^Co-Authored-By:.*$",
    rb"(?im)^Generated (with|by).*$",
    rb"(?im)^AI-Assisted:.*$",
    rb"(?im)^AI-Generated:.*$",
    rb"(?im)^Created (with|by).*(claude|copilot|cursor|codex|chatgpt|openai|anthropic|gemini).*$",
    rb"(?im)^.*claude\.ai/code.*$",
    rb"(?im)^\xf0\x9f\xa4\x96.*$",  # lines starting with the robot emoji
]

for p in patterns:
    message = re.sub(p, b"", message)

# collapse resulting blank-line runs
message = re.sub(rb"\n{3,}", b"\n\n", message).strip() + b"\n"
'
```

Note: `git-filter-repo` refuses to run on a repo without a fresh clone by
default (it wants a disposable copy). Run it on a fresh `git clone
--no-local` of the repo, verify the result, then push that clone.

## Fallback: git filter-branch

Only if `git-filter-repo` truly isn't available:

```bash
git filter-branch --msg-filter '
sed -E \
  -e "/^Co-Authored-By:/Id" \
  -e "/^Generated (with|by)/Id" \
  -e "/^AI-Assisted:/Id" \
  -e "/^AI-Generated:/Id" \
  -e "/^Created (with|by).*(claude|copilot|cursor|codex|chatgpt|openai|anthropic|gemini)/Id" \
  -e "/claude\.ai\/code/Id"
' -- --all
```

`filter-branch` is slow and leaves refs under `refs/original/` — clean those
up after verifying the result:

```bash
git for-each-ref --format="%(refname)" refs/original/ | xargs -r -n1 git update-ref -d
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

## After rewriting

1. Re-run `scripts/verify.sh` to confirm the history is clean.
2. `git push --force-with-lease` to the remote (never plain `--force`,
   and only after explicit confirmation from the user — this is a
   shared-history rewrite, not a local cleanup).
3. Tell any collaborators to re-clone or run
   `git fetch && git reset --hard origin/<branch>` on their local copies.
