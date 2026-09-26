---
name: readme-instructions
description: Create or update concise, command-oriented English README files for GitHub software repositories. Use when Codex needs to document installation, configuration, usage, development, testing, building, deployment, troubleshooting, or contribution workflows from verified repository evidence, while applying restrained GitHub-friendly visual structure.
---

# GitHub Repository README

Create a scannable project README that helps a developer run the software quickly. Prefer verified commands, configuration, and examples over explanatory prose.

## Establish the Source of Truth

1. Read the existing README and repository instructions.
2. Inspect the files that define the real developer interface, as applicable:
   - package manifests, lockfiles, and runtime-version files;
   - `Taskfile`, `Makefile`, project scripts, and executable help output;
   - `.env.example` and checked-in configuration examples;
   - Docker, Compose, CI, build, test, and deployment configuration;
   - application entry points, CLI commands, routes, and representative tests.
3. Preserve the repository's package manager, runtime, task runner, paths, ports, and terminology.
4. Never invent commands, flags, prerequisites, environment variables, URLs, features, badges, or support claims.
5. Run safe, non-destructive validation commands when feasible. If execution is unavailable, verify against repository files and do not claim the command was run.

## Structure by Reader Workflow

Use only sections supported by the project. Prefer this order:

1. Project name, one-sentence purpose, and optional logo or banner.
2. Small badge row for verified, maintained signals only.
3. Quick start with the shortest working command path.
4. Installation and prerequisites.
5. Configuration.
6. Usage and command examples.
7. Development, test, lint, build, and deployment commands.
8. Troubleshooting for known, evidenced failures.
9. Contributing, security, support, and license links when those files exist.

Add a table of contents only when the README is long enough to benefit from one. Keep the quick start near the top.

## Be Command-Oriented

- Write in English unless the user requests another language.
- Keep prose to the minimum needed to identify the project, prerequisites, constraints, and side effects.
- Prefer copyable commands and concrete configuration over narrative explanation.
- Start procedural steps with direct verbs.
- Put each logical command sequence in a fenced block with the correct language identifier.
- Keep unrelated commands in separate blocks; keep commands that must run together in the same block.
- Show the working directory when a command depends on it.
- Use placeholders such as `<api-key>` only for user-specific values, and define each placeholder once.
- Include expected output only when it helps confirm success or diagnose failure.
- Explain ordering requirements, destructive effects, security constraints, and non-obvious failure conditions even when brevity is preferred.
- Move architecture, design rationale, and long operational material to existing files under `docs/` and link to them.

## Use GitHub-Friendly Presentation

Use GitHub Flavored Markdown and restrained visual elements to improve scanning:

- Use one `#` heading for the project name and a consistent heading hierarchy below it.
- Use relative links for files and repository-owned images.
- Give every informative image meaningful alt text.
- Use tables for compact command, option, compatibility, or environment-variable references.
- Use GitHub alerts only for important notes, warnings, or destructive operations.
- Add screenshots or short demos only when they explain a GUI or observable behavior better than commands.
- Add badges only when their targets and values are verifiable from repository configuration.
- Prefer static, repository-owned assets over fragile third-party widgets.
- Keep visual decoration subordinate to installation and usage.

Do not copy profile-README conventions into a software repository README. Avoid personal statistics, visitor counters, contribution streaks, typing animations, decorative GIFs, trophy cards, social widgets, and large collections of technology badges unless the user explicitly requests a profile README.

## Command Reference Pattern

Use a compact table when a project exposes several stable tasks:

```markdown
## Commands

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start the development server. |
| `npm test` | Run the test suite. |
| `npm run build` | Create the production build. |
```

Replace the example commands with commands verified in the target repository. Do not assume Node.js or npm.

## Quick Start Pattern

````markdown
## Quick start

```bash
<verified-install-command>
<verified-run-command>
```

Open `<verified-url-or-output>`.
````

Omit the final sentence when the repository does not define a URL or observable output.

## Verify Before Handoff

- Confirm every documented command, flag, path, variable, port, and URL against repository evidence.
- Confirm code fences use the correct language and commands preserve required line continuations.
- Confirm relative links, section links, and local image paths resolve from the README location.
- Confirm the heading hierarchy renders cleanly in GitHub Flavored Markdown.
- Confirm the quick start describes the shortest supported path from a clean checkout.
- Remove duplicated instructions, generic marketing copy, speculative features, and decorative clutter.
- Preserve accurate content outside the requested scope.
