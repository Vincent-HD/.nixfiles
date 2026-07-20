---
name: reference-repository
description: Manages cloned reference repositories for pattern mining and comparison. Defaults to a named clone under ~/.references for global sharing, with a per-project .references clone as the escape hatch. Covers both add and read workflows.
---

# Reference Repository — Add & Read

## Overview

Reference repos live in `~/.references/<name>` by default — shared globally so the same repo is cloned once. The only project-local file is `reference-repos.md` at the project root, which lists the references used by that project with project-specific reasons.

**Escape hatch**: when the user explicitly says "add locally", "project-local", or "in the repo", use `<project_root>/.references/<name>` instead.

## Adding a Reference

1. Determine the target name, clone URL, and project-specific reason.
2. Choose the clone path:
   - **Default**: `~/.references/<name>`.
   - **Explicit local**: `<project_root>/.references/<name>`.
3. If the path already exists:
   - `cd <path> && git fetch origin`
   - Compare HEAD with `@{upstream}`:
     - **Behind**: `git pull` (stale clone, safe to fast-forward).
     - **Ahead** or **diverged**: do nothing — user has local changes.
4. If missing: `git clone <url> <path>`.
5. Ensure `AGENTS.md` exists at the clone root (create a minimal one with name, URL, purpose if missing).
6. Update the project's `reference-repos.md` table.

## Reading a Reference

1. Resolve the path — check in order:
   - `<project_root>/.references/<name>` (backward compat for pre-refactor clones).
   - `~/.references/<name>` (global default).
2. Consult `reference-repos.md` for the curated list.
3. Read `AGENTS.md` at the clone root first.
4. Use targeted searches (ast-outline, grep) for patterns, conventions, and implementations.
5. Summarize with exact file:line references.

## reference-repos.md Format

```
| Name | URL | Path | Why |
| --- | --- | --- | --- |
| <name> | <url> | <clone-path> | <project-specific reason> |
```

The `Path` column records the actual clone location (`~/.references/<name>` or `.references/<name>`). The `Why` column is project-specific — the same repo may be kept for different reasons across projects.

## Git Update Rules

When the clone already exists and is on the default branch:

1. `git rev-parse --abbrev-ref origin/HEAD` to determine the remote's default branch, then strip the `origin/` prefix.
2. `git fetch origin`.
3. `git rev-list --left-right --count origin/<default>...HEAD`
   - `<behind> 0` (behind only): `git merge --ff-only origin/<default>`.
   - `0 <ahead>` (ahead only): skip — user has local changes or unpushed work.
   - Both non-zero (diverged): warn the user and ask how to proceed.
