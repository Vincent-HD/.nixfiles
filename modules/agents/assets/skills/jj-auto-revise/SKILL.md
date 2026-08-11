---
name: jj-auto-revise
description: >
  Keep Jujutsu work as one open revision at a time: describe at the start of a piece of work,
  do not commit when that piece ends, and on each new user prompt either continue editing the
  same rev or jj commit then describe the new concern. Prefer absorb/squash-into for follow-ups
  to recent ancestors. Use when implementing with jj, or when the user says "jj", "absorb",
  "describe", "jj commit", "as usual with jj".
---

# jj auto-revise

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds; otherwise use the short git fallback.

**Never** `git push`, `jj git push`, or any remote push.

Companion for later squash→resplit into a stacked PR: `jj-resplit-stack`.

## Core loop (prompt boundary)

Work stays on **one open revision** (`@`) while the user is still on that concern.

| Moment | Action |
| ------ | ------ |
| **Start** of a piece of work (or when `@` is still empty / untitled `wip`) | `jj describe` the current concern (why-focused, conventional). Then edit files. |
| **During** that piece (same prompt or follow-ups on the same ask) | Keep editing `@`. Do **not** `jj commit` / `jj new` just because a sub-step finished. Touch `jj describe` only if the meaning of the work changed in a **very meaningful** way (scope flip, wrong title, split concern). |
| **End** of a piece of work | Do **not** commit. Leave the described rev open. |
| **Each new user prompt** | Compare the ask to `@`’s description (and the diff). **Related** → continue editing; leave the description alone unless a very meaningful rename is needed. **Unrelated** → `jj commit` (finalizes the previous rev and opens a new `@`), then `jj describe` the new concern, then edit. |

`jj commit -m "…"` is fine when the previous rev still needs a final message; if it is already well described, `jj commit` without changing the message (or commit then describe only the new `@`) is enough. Prefer not rewriting a good prior description.

### Related vs unrelated

Treat the new prompt as **related** when it continues the same reviewable unit (same feature/fix/docs topic, same bug, polish/tests/docs for that same change).

Treat it as **unrelated** when it is a new feature, a different bug, a separable refactor, or would make `@`’s description a lie if mashed in. When unsure, ask once — or commit and start clean rather than kitchen-sink `@`.

## Secondary tools (same concern, wrong rev)

Use these when the change belongs with history **other than** the open `@`, or when `@` is mixed:

| Situation | Action |
| --------- | ------ |
| Small follow-up to a **recent mutable ancestor** (same lines/files) | Prefer `jj absorb` |
| Same concern as a **known** ancestor; absorb ambiguous | `jj squash --from @ --into <rev> [paths…]` |
| WC mashed unrelated topics | `jj split <filesets…>` (non-interactive), describe each side |
| Empty accidental `wip` | `jj abandon <rev>` |

After absorb/squash → verify with `jj op show -p` and/or `jj log` + `jj diff -r <rev>`.

### Meaningful vs noise

Do **not** open a new rev (via commit-on-new-prompt) for drive-by noise that still belongs to the open concern:

- typo / import / comment on the change already described in `@`
- docs that only document that same change
- test fix for an assertion introduced in that same concern

Those stay on `@` (or absorb/squash-into the ancestor that owns them).

## Command cookbook

```bash
jj root
jj status
jj log -n 15
jj diff -r @
jj op show -p

# Name the open piece of work (start / retitle only when meaningful)
jj describe -m "$(cat <<'EOF'
feat(scope): why this change exists

EOF
)"

# New prompt is unrelated: finalize previous @ and open a new empty WC
jj commit -m "$(cat <<'EOF'
feat(scope): why the previous change exists

EOF
)"
# then describe the new @ if the commit message was for the old rev only:
jj describe -m "$(cat <<'EOF'
feat(other): why the new change exists

EOF
)"

jj absorb
jj absorb path/to/file path/to/dir
jj absorb -f @ -t 'mutable()'

jj squash --from @ --into <rev> -m "$(cat <<'EOF'
feat(scope): updated why

EOF
)"
jj squash --from @ --into <rev> path/a path/b

jj split path/a path/b -m "$(cat <<'EOF'
fix(scope): first slice why

EOF
)"

jj abandon <rev>
jj bookmark set my-topic -r @   # local only
```

### Notes

- **`jj commit`:** records the current change and starts a new empty one on top (describe+new). Use at **prompt boundaries** when the ask switched concerns — not at the end of a turn that finished a sub-step of the same ask.
- **`jj describe`:** names `@` at the beginning (or mid-flight only for a meaningful retitle). Do not re-describe every turn.
- **Absorb:** closest mutable ancestor that last touched those lines; ambiguous hunks stay in source.
- **Split:** filesets preferred; avoid `-i` when paths suffice.
- **Squash:** prefer explicit `--from` / `--into` over bare squash-into-parent.

## Git fallback (no jj)

Still **no push**. Same concern as HEAD → keep editing / amend only if user rules allow. New unrelated prompt → new path-staged commit. No absorb equivalent.

## Anti-patterns

- `jj commit` / `jj new` at the end of every agent turn “to be safe”
- Re-describing `@` every prompt when the concern did not change
- Mashing an unrelated user ask into `@` because commit feels heavy
- New rev per drive-by lint on the open concern
- Describing a mixed WC with a message that covers half the diff
- Any push / force-push
- Interactive `jj split -i` / `jj squash -i` when filesets suffice
