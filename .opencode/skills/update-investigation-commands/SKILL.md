---
name: update-investigation-commands
description: Maintains `INVESTIGATION_COMMANDS.md` for this nixfiles repo by collecting reusable shell command patterns from the current session, merging duplicates, normalizing commands into reusable templates, and keeping `README.md` linked to the reference. Use when a session in this repo involves meaningful shell-based investigation, debugging, evaluation, validation, or runtime inspection.
---

# Update Investigation Commands

## Purpose

Keep `INVESTIGATION_COMMANDS.md` useful across sessions instead of letting it turn into a raw transcript of one-off commands.

This is a project skill for this repo. It should be applied when shell commands used during the session reveal reusable investigation patterns.

## Files

- Main reference: `INVESTIGATION_COMMANDS.md`
- Discoverability link: `README.md`

## When To Use

Use this skill when working in this repo and the session includes command-line investigation such as:

- flake or input discovery
- `nix eval` exploration
- generated config inspection
- `niri` / `noctalia-shell` runtime checks
- validation or formatting commands
- debugging a failed rebuild, activation, or session behavior

Skip updates when the session had no meaningful new command patterns.

## Update Workflow

1. Review the shell commands used during the session.
2. Keep only commands that are likely to help in a future session.
3. Update `INVESTIGATION_COMMANDS.md` intelligently:
   - add genuinely new reusable patterns
   - merge near-duplicates
   - replace overly specific paths or values with reusable placeholders when appropriate
   - keep concise explanations of purpose and when to use each command
4. Put low-reuse or one-off commands in the session-specific / low-reuse section instead of mixing them into the main reference.
5. If an existing entry already covers the same pattern, improve that entry rather than duplicating it.
6. Remove or rewrite stale entries if the current session found a better or more correct pattern.
7. Ensure `README.md` links to `INVESTIGATION_COMMANDS.md`; add the link only if it is missing.

## Editing Rules

- Do not dump raw shell history into the file.
- Do not add tiny one-line variants mechanically if a single normalized pattern covers them.
- Prefer grouped command families over repeated isolated commands.
- Preserve readability: short explanations, consistent formatting, practical examples.
- Keep repo-specific knowledge that matters, such as common placeholders or required `NIX_CONFIG` flags.

## Good Reference Entries

Each reusable entry should usually include:

- a short title
- a normalized command
- a brief purpose
- optional notes on when to use it

## Repo-Specific Notes

- This repo often needs:

```bash
NIX_CONFIG='extra-experimental-features = nix-command flakes dynamic-derivations'
```

for some `nix eval` commands.

- Prefer documenting commands in reusable forms with placeholders like:

```bash
REPO=/home/vincent/.nixfiles
HOST=pc-fixe
USER=vincent
```

- If a command has immediate visible side effects, say so in the note.

## Completion Checklist

- `INVESTIGATION_COMMANDS.md` updated only if the session added value
- duplicate or overlapping entries merged
- low-reuse commands kept separate
- stale entries corrected if needed
- `README.md` still links to `INVESTIGATION_COMMANDS.md`
