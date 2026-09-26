#!/usr/bin/env python3
"""Validate the shared Conventional Commit + .memory trailer standard."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# <type>(<scope>)<!> directly followed by ": <shape> - <description>" (no dot padding)
SUBJECT_RE = re.compile(
    r"^(?P<type>[a-z][a-z0-9-]*)(?:\([a-z0-9._/\-]{1,8}\))?!?: "
    r"(?P<shape>\S) - \S.*$"
)
SHAPES = {
    "fix": "●", "perf": "△", "refactor": "◆", "feat": "▲", "docs": "□", "style": "◇",
    "build": "■", "ci": "■", "chore": "○", "test": "○", "revert": "○",
}
ROOT_SUBJECT = "init: ○ - 🌱."
MEMORY_TRAILER_RE = re.compile(r"^(Memory-Ref|Decision-Ref):\s+(.+)$")
AI_RE = re.compile(
    r"(?i)(co-authored-by:.*(?:claude|copilot|cursor|codex|chatgpt|openai|anthropic|gemini)|"
    r"generated[ -]with|ai-assisted:|ai-generated:|claude\.ai/code|\[(?:claude-code|copilot|cursor|codex)\])"
)


def fail(message: str) -> None:
    print(f"commit-convention: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("message_file", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()

    text = args.message_file.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or not lines[0].strip():
        fail("commit message has no subject")

    subject = lines[0].strip()
    m = SUBJECT_RE.match(subject)
    if subject != ROOT_SUBJECT:
        if not m:
            fail(
                "subject does not match the standard; expected "
                "<type>[(scope)][!]: <shape> - <description>'"
            )
        if m.group("type") not in SHAPES:
            fail(f"unknown type: {m.group('type')}")
        if m.group("shape") != SHAPES[m.group("type")]:
            fail(f"type {m.group('type')} needs shape {SHAPES[m.group('type')]}, got {m.group('shape')}")

    if AI_RE.search(text):
        fail("message contains prohibited AI/agent attribution")

    repo = args.repo.resolve()
    for raw in lines:
        m = MEMORY_TRAILER_RE.match(raw.strip())
        if not m:
            continue
        key, value = m.groups()
        ref = value.strip()
        if not ref.startswith(".memory/") or not ref.endswith(".md"):
            fail(f"{key} must reference a .memory/*.md path: {ref}")
        candidate = (repo / ref).resolve()
        try:
            candidate.relative_to(repo)
        except ValueError:
            fail(f"{key} escapes repository root: {ref}")
        if not candidate.exists():
            fail(f"{key} points to a missing file: {ref}")
        if key == "Decision-Ref" and not ref.startswith(".memory/decisions/"):
            fail(f"Decision-Ref must point under .memory/decisions/: {ref}")

    print("commit-convention: commit message matches the shared standard")


if __name__ == "__main__":
    main()
