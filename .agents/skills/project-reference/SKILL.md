---
name: reference-projects
description: Workflow for managing and browsing reference projects — cloned third-party repos kept locally in references/ for comparison. Load when the user asks to compare with references, add/update a reference, or look at how other projects handle something. Trigger phrases include "compare with references", "compare with others", "reference projects", "add a reference", "update references", "how do others do".
---

# Reference Projects

Reference repos live in `references/` at the project root. They are gitignored and never modified.

**Only use this when the user explicitly asks.** Do not proactively search references.

## Check Existing References

```bash
ls references/
```

To see where a reference came from:

```bash
git -C references/<name> remote -v
```

## Add a Reference

```bash
git clone --depth 1 https://github.com/<owner>/<repo>.git references/<owner>_<repo>
```

Ensure `references` is in `.gitignore`:

```
references
```

## Update a Reference

```bash
git -C references/<name> pull
```

If shallow clone fails, re-clone:

```bash
rm -rf references/<name>
git clone --depth 1 <url> references/<name>
```

## Browse References

**Use regular tools** — glob, grep, read — not GitHub MCP. The references are local.

1. List available references: `ls references/`
2. Use Task tool with `explore` agent, set path to `references/` or a specific folder
3. Read files directly with Read tool

Example: "How does librephoenix handle audio?" → explore references/ for audio-related files, read relevant config files, summarize findings.

## Rules

- **Always explore on local copy** — do not open GitHub links for references
- **Never commit** references — keep them gitignored
- **Never modify** files in references/ — they are read-only