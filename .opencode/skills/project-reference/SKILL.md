---
name: project-reference
description: Workflow for managing and browsing reference projects cloned into a local `references/` folder for comparison and inspiration. Load when the user asks to compare with references, add or update a reference, or inspect how other projects handle something.
compatibility: opencode
---

# Reference Projects

A reference project is a cloned third-party repo kept locally for comparison and inspiration. They live in `references/` at the project root, are gitignored, and are never modified.

Only use this workflow when the user explicitly asks. Do not proactively search references.

## Discovery

Check what references exist in the current project:

```bash
ls references/
```

To see where a reference came from:

```bash
git -C references/<name> remote -v
```

If there is no `references/` directory, the project has no references yet.

## Adding a Reference

1. Clone into `references/` using the naming guideline `<owner>_<repo-name>`:

```bash
git clone --depth 1 https://github.com/<owner>/<repo>.git references/<owner>_<repo>
```

`--depth 1` keeps it lightweight. The `owner_repo` naming convention is a guideline, not a strict rule - the user may choose a different name.

2. Ensure `references` is listed in the project's root `.gitignore`. If it is missing, add it:

```text
references
```

## Updating References

Pull the latest changes:

```bash
git -C references/<name> pull
```

If the clone is shallow and pull fails, re-clone:

```bash
rm -rf references/<name>
git clone --depth 1 <remote-url> references/<name>
```

## Browsing and Comparing

When the user asks to compare or look at how others handle something:

1. List available references so the user knows what is available.
2. Use the Task tool with the `explore` agent to search across reference projects. Set the path to `references/` or a specific reference directory.
3. Read relevant files with the Read tool for detailed comparison.

Example prompts the user might give:

- "How does librephoenix handle audio?"
- "Compare my niri config with the references"
- "Search all references for hyprland setup"

When presenting findings, summarize the approach each reference takes and highlight differences or ideas worth adopting.

## Hygiene

- Never commit reference repos - they must stay gitignored.
- Never modify files inside `references/`. They are read-only exemplars.
- Clean up references the user no longer needs: `rm -rf references/<name>`.
- References are disposable - they can always be re-cloned.
