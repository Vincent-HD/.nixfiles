---
name: jj-auto-revise
description: >
  Keep Jujutsu work as one open revision at a time: print a progress block at prompt
  boundaries, describe at the start of a piece of work, do not commit when that piece
  ends, and on each new user prompt either continue editing the same rev or jj commit
  then describe the new concern. Prefer absorb/squash-into for follow-ups to recent
  ancestors. Use when implementing with jj, or when the user says "jj", "absorb",
  "describe", "jj commit", "as usual with jj".
---

# jj auto-revise

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds; otherwise use the short git fallback.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companions: later squash→resplit into a stacked PR → `jj-resplit-stack`. Conflicted `@` / rebase / merge → `jj-solve-conflict`. This skill only keeps **one open `@`** while the user is on that concern. Extra recipes: [reference.md](reference.md).

## Hard rules

- One open `@` per concern. Do **not** `jj commit` / `jj new` at the end of a turn that finished a sub-step of the same ask.
- Print the **progress block** at prompt boundaries (related vs unrelated) and before/after absorb, squash, or split. Not after every file edit.
- HEREDOC `-m` or `--use-destination-message`. Never open an editor (`nano` / `$EDITOR`).
- No interactive `-i`. No push. No backup/duplicate stacks (companions own those).
- `@` is conflicted → one sentence: stop, use `jj-solve-conflict`. Do not inline that workflow.
- User asks to resplit history / stacked PRs / squash-blob-onto-main → one sentence: use `jj-resplit-stack`.

## Progress (mandatory)

At each **new user prompt** (deciding related vs unrelated) and when absorbing, squashing, or splitting, print this block. Fill it from the inspect commands. Do not wait until the end of the turn. Skip it while only editing files on an already-decided `@`.

```markdown
**Concern:** `<@ description first line>` (`change_id`)
**WC:** empty | N files | mixed (topics: …)
**This prompt:** related | unrelated | absorb-into `<rev>` | squash-into `<rev>` | split
**Action:** continue editing @  |  jj commit → describe new  |  absorb/squash/split then continue
```

If `@` is conflicted, **Action** is: stop — use `jj-solve-conflict`.

Optional helper (same directory as this skill):

```bash
bash ~/.agents/skills/jj-auto-revise/scripts/status.sh
```

## Core loop (prompt boundary)

Work stays on **one open revision** (`@`) while the user is still on that concern.

| Moment | Action |
| ------ | ------ |
| **Start** of a piece (or `@` still empty / untitled `wip`) | `jj describe` the current concern (why-focused, conventional). Then edit files. |
| **During** that piece (same prompt or follow-ups on the same ask) | Keep editing `@`. Do **not** `jj commit` / `jj new` because a sub-step finished. Touch `jj describe` only if the meaning changed in a **very meaningful** way (scope flip, wrong title, split concern). |
| **End** of a piece | Do **not** commit. Leave the described rev open. |
| **Each new user prompt** | Inspect `@` (block above). **Related** → continue editing; leave the description alone unless a very meaningful rename is needed. **Unrelated** → `jj commit` (finalizes the previous rev and opens a new empty `@`), then `jj describe` the new concern, then edit. |

`jj commit` = describe + new empty WC. Use it at **prompt boundaries** when the ask switched concerns. Always pass `-m` so no editor opens. If the previous rev is already well described, pass that same text (do not invent a rewrite). Then `jj describe` only the new `@`. Prefer not rewriting a good prior description.

### Related vs unrelated

**Related:** same reviewable unit (same feature/fix/docs topic, same bug, polish/tests/docs for that same change). Drive-by noise that belongs to the open concern stays on `@`: typo / import / comment on that change; docs that only document it; test fix for an assertion it introduced.

**Unrelated:** a new feature, a different bug, a separable refactor, or anything that would make `@`’s description a lie if mashed in. When unsure, ask once — or commit and start clean rather than kitchen-sink `@`.

## Absorb vs squash vs split

Use these when the change belongs with history **other than** the open `@`, or when `@` is mixed. Print the progress block first.

| Situation | Command |
| --------- | ------- |
| Small follow-up to a **recent mutable ancestor** (same lines) | `jj absorb [paths…]` — hunks go to the closest mutable ancestor that last touched those lines; leftover hunks stay in source |
| Same concern as a **known** ancestor; absorb ambiguous or you already know the rev | `jj squash --from @ --into REV [paths…]` with `--use-destination-message` unless you are **intentionally** rewriting the ancestor message |
| WC mashed unrelated topics | `jj split path/a path/b -m "…"` (filesets, no `-i`), then describe each side |
| Empty accidental `wip` | `jj abandon REV` |

Before absorb/squash, note `OP=$(jj op log -n 1 -T 'self.id().short()' --no-graph)` — safety net for `jj undo`, not a backup ritual. After: `jj op show -p` and `jj diff -r REV --summary`.

Do **not** open a new rev (via commit-on-new-prompt) for drive-by noise that still belongs to the open concern — stay on `@`, or absorb/squash-into the ancestor that owns those lines.

## Inspect (before deciding)

```bash
jj root
jj status

jj log -r @ --no-graph \
  -T 'change_id.short() ++ " empty=" ++ empty ++ " conflict=" ++ conflict ++ " " ++ description.first_line() ++ "\n"'

jj diff -r @ --summary

# nearby targets for absorb/squash
jj log -r 'ancestors(@-) & mutable()' -n 8 --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
```

`empty=true` with an untitled `wip` → describe, then edit. `conflict=true` → stop, `jj-solve-conflict`. File list vs description disagree on topic → **mixed** → split (or unrelated commit), do not describe the mash as one concern.

## Command cookbook

```bash
# Name the open piece (start / meaningful retitle only)
jj describe -m "$(cat <<'EOF'
feat(scope): why this change exists

EOF
)"

# New prompt is unrelated: finalize previous @ (always -m; no editor)
jj commit -m "$(cat <<'EOF'
feat(scope): why the previous change exists

EOF
)"
# then name the new empty @:
jj describe -m "$(cat <<'EOF'
feat(other): why the new change exists

EOF
)"

# Absorb (paths optional). Leftover hunks stay in @.
OP=$(jj op log -n 1 -T 'self.id().short()' --no-graph)
jj absorb
jj absorb path/to/file path/to/dir
jj op show -p
jj diff -r <ancestor> --summary

# Squash into a known ancestor — keep its message
jj squash --from @ --into REV --use-destination-message
jj squash --from @ --into REV --use-destination-message path/a path/b

# Squash and rewrite the ancestor message (rare; only when intentional)
jj squash --from @ --into REV -m "$(cat <<'EOF'
feat(scope): updated why

EOF
)"

# Split mixed @ by filesets; -m names the selected side; remaining keeps the old message
jj split path/a path/b -m "$(cat <<'EOF'
fix(scope): first slice why

EOF
)"
# then inspect log and describe the remaining side if the old message is now a lie

jj abandon REV
# jj bookmark set my-topic -r @   # local only; not the point of this skill
```

### Notes

- **`jj commit`:** records `@` and starts a new empty WC (describe+new). Prompt-boundary only. Path-args `jj commit FILESETS` is a split-like move — do not use it as the unrelated-prompt commit; use `jj split` when you mean split.
- **`jj describe`:** names `@` at the beginning (or mid-flight only for a meaningful retitle). Do not re-describe every turn.
- **`jj absorb`:** closest mutable ancestor that last touched those lines (`-f @` / `-t mutable()` are the defaults). Ambiguous hunks stay in source. Source is abandoned only if everything absorbed **and** source had no description.
- **`jj squash`:** always `--from` / `--into`. `--use-destination-message` unless rewriting the ancestor. Bare squash opens an editor if both sides have descriptions.
- **`jj split`:** filesets required for non-interactive use (`-i` is the default with no paths). Selected stay in the original rev; remaining become a child. Avoid `-i`.
- Extra flags and leftover-hunk recipes: [reference.md](reference.md).

## Git fallback (no jj)

Still **no push**. Same concern as HEAD → keep editing / amend only if user rules allow. New unrelated prompt → new path-staged commit. No absorb equivalent.

## Anti-patterns

- `jj commit` / `jj new` at the end of every agent turn “to be safe”
- Re-describing `@` every prompt when the concern did not change
- Mashing an unrelated user ask into `@` because commit feels heavy
- New rev per drive-by lint on the open concern
- Describing a mixed WC with a message that covers half the diff
- Bare `jj squash` / `jj commit` / `jj describe` / `jj split` without `-m` or `--use-destination-message` (opens an editor)
- Rewriting an ancestor message on absorb/squash when you only meant to land a follow-up
- Inventing a backup/duplicate bookmark ritual (that is `jj-resplit-stack` / `jj-solve-conflict`)
- Resolving conflicts or resplitting a stack in this skill
- Interactive `jj split -i` / `jj squash -i` / `jj absorb -i` when filesets suffice
- Any push / force-push
- Hand-symlinking this skill into `~/.agents/skills` (Home Manager owns that path)
