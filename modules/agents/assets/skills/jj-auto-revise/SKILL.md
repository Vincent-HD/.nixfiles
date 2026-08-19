---
name: jj-auto-revise
description: >
  Keep Jujutsu work as one open revision at a time: print a progress block at prompt
  boundaries, describe at the start of a piece of work, do not commit when that piece
  ends. On each new prompt, keep nits, docs, and small extras on @; jj commit then
  describe only for a substantial new concern; ask if unsure. Prefer absorb/squash-into
  for follow-ups to recent ancestors. Use when implementing with jj, or when the user
  says "jj", "absorb", "describe", "jj commit", "as usual with jj".
---

# jj auto-revise

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds; otherwise use the short git fallback.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companions: later squash→resplit into a stacked PR → `jj-resplit-stack`. Conflicted `@` / rebase / merge → `jj-solve-conflict`. This skill only keeps **one open `@`** while the user is on that concern. Extra recipes: [reference.md](reference.md).

## Hard rules

- One open `@` per concern. Do **not** `jj commit` / `jj new` at the end of a turn that finished a sub-step of the same ask.
- Print the **progress block** at prompt boundaries (stay vs new rev) and before/after absorb, squash, or split. Not after every file edit.
- HEREDOC `-m` or `--use-destination-message`. Never open an editor (`nano` / `$EDITOR`).
- No pager. Agent shells are PTYs: bare `jj status` / `jj log` / `jj diff` / `jj op *` / `jj help` / `jj bookmark list` / `jj config list` open `less` and hang forever (often with empty captured output). `timeout(1)` does not help — `less` ignores SIGTERM. Prefix **every** standalone `jj` (and `git log` / `git diff`) with `PAGER=cat GIT_PAGER=cat`. Exports do not persist across agent shell calls. Helper scripts already set this plus `ui.paginate=never`. Never `jj op show -p` unpiped — use `| head`.
- No interactive `-i`. No push. No backup/duplicate stacks (companions own those).
- `@` is conflicted → one sentence: stop, use `jj-solve-conflict`. Do not inline that workflow.
- User asks to resplit history / stacked PRs / squash-blob-onto-main → one sentence: use `jj-resplit-stack`.

## Progress (mandatory)

At each **new user prompt** (deciding stay vs new rev) and when absorbing, squashing, or splitting, print this block. Fill it from the inspect commands. Do not wait until the end of the turn. Skip it while only editing files on an already-decided `@`.

```markdown
**Concern:** `<@ description first line>` (`change_id`)
**WC:** empty | N files | mixed (topics: …)
**This prompt:** stay-on-@ | new-rev | absorb-into `<rev>` | squash-into `<rev>` | split
**Action:** continue editing @  |  jj commit → describe new  |  absorb/squash/split then continue
```

If `@` is conflicted, **Action** is: stop — use `jj-solve-conflict`.

Optional helper (same directory as this skill; disables the pager itself):

```bash
bash ~/.agents/skills/jj-auto-revise/scripts/status.sh
```

Do **not** run raw `jj status` / `jj help` / `jj op show -p` to fill this block.

## Core loop (prompt boundary)

Work stays on **one open revision** (`@`) while the user is still on that concern.

| Moment | Action |
| ------ | ------ |
| **Start** of a piece (or `@` still empty / untitled `wip`) | `jj describe` the current concern (why-focused, conventional). Then edit files. |
| **During** that piece (same prompt or follow-ups on the same ask) | Keep editing `@`. Do **not** `jj commit` / `jj new` because a sub-step finished. Touch `jj describe` only if the meaning changed in a **very meaningful** way (scope flip, wrong title, split concern). |
| **End** of a piece | Do **not** commit. Leave the described rev open. |
| **Each new user prompt** | Inspect `@` (block above). **Small extra** (nit, docs, copy, tests, tiny ask) → stay on `@`. **Substantial new concern** → `jj commit` (finalizes the previous rev and opens a new empty `@`), then `jj describe` the new concern, then edit. **Unsure** → ask once. |

`jj commit` = describe + new empty WC. Use it at **prompt boundaries** only for a substantial new concern. Always pass `-m` so no editor opens. If the previous rev is already well described, pass that same text (do not invent a rewrite). Then `jj describe` only the new `@`. Prefer not rewriting a good prior description.

### Same rev vs new rev

Default: **keep editing `@`**. Prefer fewer revisions while the user is still in the same stretch of work. Peeling history later is `jj-resplit-stack`, not prompt-boundary splits.

Stay on `@` when the new ask is a nit, docs, copy, tests, or any other **small** extra — even if it is not the same topic as the current description.

Open a new rev (`jj commit` then describe) only when the new ask is a **substantial** new concern: a full feature, a different bug of similar size, or a refactor large enough to stand alone.

When unsure whether the extra is small enough to keep: **ask once**. Do not split by default.

## Absorb vs squash vs split

Use these when the change belongs with history **other than** the open `@`, or when `@` is mixed. Print the progress block first.

| Situation | Command |
| --------- | ------- |
| Small follow-up to a **recent mutable ancestor** (same lines) | `jj absorb [paths…]` — hunks go to the closest mutable ancestor that last touched those lines; leftover hunks stay in source |
| Same concern as a **known** ancestor; absorb ambiguous or you already know the rev | `jj squash --from @ --into REV [paths…]` with `--use-destination-message` unless you are **intentionally** rewriting the ancestor message |
| WC mixed with two **substantial** topics | `jj split path/a path/b -m "…"` (filesets, no `-i`), then describe each side |
| Empty accidental `wip` | `jj abandon REV` |

Before absorb/squash, note `OP=$(PAGER=cat jj op log -n 1 -T 'self.id().short()' --no-graph)` — safety net for `jj undo`, not a backup ritual. After: `PAGER=cat jj op show -p | head -n 80` and `PAGER=cat jj diff -r REV --summary`.

Do **not** open a new rev (via commit-on-new-prompt) for drive-by noise that still belongs to the open concern — stay on `@`, or absorb/squash-into the ancestor that owns those lines.

## Inspect (before deciding)

```bash
# prefer the helper (sets PAGER + ui.paginate=never):
#   bash ~/.agents/skills/jj-auto-revise/scripts/status.sh
#
# every standalone jj in a new agent shell:
PAGER=cat GIT_PAGER=cat jj root
PAGER=cat GIT_PAGER=cat jj log -r @ --no-graph \
  -T 'change_id.short() ++ " empty=" ++ empty ++ " conflict=" ++ conflict ++ " " ++ description.first_line() ++ "\n"'
PAGER=cat GIT_PAGER=cat jj diff -r @ --summary
PAGER=cat GIT_PAGER=cat jj log -r 'ancestors(@-) & mutable()' -n 8 --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
```

`empty=true` with an untitled `wip` → describe, then edit. `conflict=true` → stop, `jj-solve-conflict`. File list vs description disagree **and both sides are substantial** → **mixed** → split or ask. A small extra next to the main topic is not mixed — keep it on `@`.

## Command cookbook

```bash
# Name the open piece (start / meaningful retitle only)
jj describe -m "$(cat <<'EOF'
feat(scope): why this change exists

EOF
)"

# New prompt is a substantial new concern: finalize previous @ (always -m; no editor)
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
OP=$(PAGER=cat jj op log -n 1 -T 'self.id().short()' --no-graph)
PAGER=cat jj absorb
PAGER=cat jj absorb path/to/file path/to/dir
PAGER=cat jj op show -p | head -n 80
PAGER=cat jj diff -r <ancestor> --summary

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

Still **no push**. Same stretch of work as HEAD → keep editing / amend only if user rules allow. Substantial new concern → new path-staged commit. Small extras stay in the current commit when rules allow amend; otherwise ask. No absorb equivalent.

## Anti-patterns

- `jj commit` / `jj new` at the end of every agent turn “to be safe”
- Re-describing `@` every prompt when the concern did not change
- Opening a new rev for a nit, docs, copy, or other small extra
- Splitting by default when unsure (ask instead)
- Describing a mixed WC with a message that covers half the diff (only when both halves are substantial)
- Bare `jj squash` / `jj commit` / `jj describe` / `jj split` without `-m` or `--use-destination-message` (opens an editor)
- Rewriting an ancestor message on absorb/squash when you only meant to land a follow-up
- Inventing a backup/duplicate bookmark ritual (that is `jj-resplit-stack` / `jj-solve-conflict`)
- Resolving conflicts or resplitting a stack in this skill
- Interactive `jj split -i` / `jj squash -i` / `jj absorb -i` when filesets suffice
- Bare `jj status` / `jj log` / `jj diff` / `jj help` / `jj op show -p` / `jj bookmark list` on an agent PTY (hangs in `less`)
- Any push / force-push
- Hand-symlinking this skill into `~/.agents/skills` (Home Manager owns that path)
