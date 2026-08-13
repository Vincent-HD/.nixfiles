---
name: antislop
description: Anti-pattern rule tracker — when you fix or refactor crappy/sloppy code, file a rule so the agent knows to avoid that pattern in the future. Optionally attach a machine-checkable pattern (ast-grep, oxlint, grit) for deterministic prevention.
---

# Antislop

When you fix or refactor sloppy code — a crappy pattern, an unnecessary abstraction, a verbose idiom, a footgun API
usage — file an anti-slop rule before moving on:

```bash
antislop add "<what to avoid and what to do instead>" --tag <area>
```

If the pattern is deterministically checkable, include a pattern:

```bash
antislop add "Prefer Effect.fn over async/await" \
  --pattern "async function" \
  --pattern-lang ast-grep \
  --prescription "Use Effect.fn instead" \
  --severity major
```

Severity: `minor` (default) for style nits, `major` for correctness risks, `blocker` for known bugs.

## Commands

```bash
  antislop add [--global] <text> [--tag <area>] [--severity minor|major|blocker]
  antislop add [--global] <text> --pattern <pattern> [--pattern-lang lang] [--prescription <text>] [--tag <area>] [--severity minor|major|blocker]
  antislop list [--global] [--format json|md] [--all]
  antislop resolve [--global] <id-prefix>
  antislop supersede [--global] <id-prefix> "<reason it is no longer relevant>"
  antislop apply [--global] <id-prefix> [--out <dir>]
  antislop gen-rule [--global] <pattern> [--lang ast-grep|oxlint|grit] [--text <description>]
  antislop clean [--global]
  antislop schema
```

## Scope

Use the repository's `.antislop.jsonl` only for anti-patterns specific to that repository's code,
conventions, and stack. Keep language-level or tooling-level rules in the global file at
`~/.antislop.jsonl`:

```bash
antislop add --global "<global rule>" --tag typescript
```

## Workflow

1. Fix/refactor slop → `antislop add "Avoid X, prefer Y instead" --tag <area> --severity minor|major|blocker`
2. If the pattern is mechanically detectable, add `--pattern <ast-grep/oxlint/grit pattern>` so it can be applied later
3. Keep working — filing takes one line
4. Periodically: `antislop list --format md` to review open rules
5. When a rule is consistently followed, resolve it with `antislop resolve <id>`
6. If a rule is no longer relevant, mark it with `antislop supersede <id> "<reason>"`
7. To generate a rule file from a pattern: `antislop apply <id> --out .antislop/`
8. Periodically prune resolved rules: `antislop clean`

## For agents

When fixing or refactoring code that contains a clear anti-pattern, file a rule:

1. `antislop add "description of what to avoid" --tag <area> --severity <level>`
2. If the pattern could be caught by a linter or static analysis, include `--pattern` and `--pattern-lang`
3. If you know the preferred alternative, include `--prescription`

Check open anti-slop rules at the start of each session and avoid the listed patterns:

```bash
antislop list --format md
```
