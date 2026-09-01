---
name: jj-resplit-stack
description: >
  Squash a messy jj (or git) stack or working copy, then resplit into meaningful
  revisions. Always preflight: squash stack-onto-trunk vs only @; how many revs or
  yolo; bookmarks per rev vs tip-only; typecheck TIP first (fail = no-go unless skip).
  Capture the current jj op id before rewriting. Then peel feature/FE-BE slices with
  tests per rev. Use when the user asks to resplit, squash and split, prepare stacked
  PRs, clean wip history, or reorganize commits by feature before review.
---

# jj resplit stack

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companions: day-to-day describe/absorb → `jj-auto-revise` (this skill is the later cleanup). Conflicted restore/peel → `jj-solve-conflict` (stop; do not resolve here).

This skill only **preflight → squash blob onto BASE → peels feature/FE-BE slices → tests each rev**. It does not run the prompt-boundary revise loop and does not resolve conflicts.

## Hard rules

- **Op restore (mandatory, first).** Before any rewrite, capture `OP=$(PAGER=cat GIT_PAGER=cat jj op log -n 1 -T 'self.id().short()' --no-graph)`. Echo `OP` in the first user-visible message. Do not create backup bookmarks or `jj duplicate` snapshots. Do not `jj op restore` unless the user asks. At the end of the run, print `jj op restore $OP`.
- **Wait on preflight** (section 1). Do not squash or peel until the user answers. Answers in the trigger message count.
- Squash peels with `--use-destination-message` so the blob's `wip: squash blob` text does not overwrite the slice `-m`, and so nano never opens.
- No interactive `-i`. No push. `jj undo` only the last step if the just-made squash is wrong.
- No pager. Agent shells are PTYs: bare `jj status` / `jj log` / `jj diff` / `jj op *` / `jj help` / `jj bookmark list` open `less` and hang forever. Prefix **every** standalone `jj` with `PAGER=cat GIT_PAGER=cat`. Helper scripts already set this plus `ui.paginate=never`. Never `jj op show -p` unpiped.
- Tests travel with the code they cover. Prefer FE/BE split when either side is reviewable alone. Typecheck + added tests on **every** peeled rev unless the user skipped typecheck.
- Never bare `jj run -r R -- <test>`: it checks out, runs, and **amends** R. Use a disposable child or a workspace.
- After abandoning a test child, `@` is empty untitled — `jj new` the next slice or `jj edit $STACK_TIP`. Do not leave those empties on the stack.
- After the new stack is verified: restore `@` to the stack tip. Ask before abandoning the old pre-squash range.
- Never `jj bookmark set` an existing PR bookmark (`push-*`, remote-tracking). **Ask only.**

## Progress (mandatory)

Every user-visible message while this skill runs includes a **progress block**. Do not wait until the end. Update it after inventory, before each peel, and after each test. Include `OP` from the first message onward.

```markdown
**OP:** `<id>` — rollback: `jj op restore <id>`
**Resplit:** step 2/5 blob-on-BASE
**BASE:** `main` (`change_id`)  **TIP:** ...
**Plan:** 1 backend 2 frontend 3 docs  (N remaining slices)
**Now:** peeling slice 2/3 — `feat(ui): …` — paths: apps/frontend …
**Blob leftover:** M files  (or “empty, abandon blob”)
**Tests:** skip | TIP fail (no-go) | rev1 typecheck+specs / …
**Bookmarks:** per-rev | tip-only
```

Steps: `1 inventory+preflight` · `2 blob-on-BASE` · `3 peel` · `4 tests` · `5 deliver`.

Extra recipes: [reference.md](reference.md).

## 1. Inventory + preflight (wait)

Read-only. If the user only wanted day-to-day describe/absorb: use `jj-auto-revise`. Stop.

```bash
PAGER=cat GIT_PAGER=cat jj root
OP=$(PAGER=cat GIT_PAGER=cat jj op log -n 1 -T 'self.id().short()' --no-graph)
echo "OP=$OP"
# helper disables the pager itself:
#   bash ~/.agents/skills/jj-resplit-stack/scripts/inventory.sh "$BASE" "$TIP"

PAGER=cat GIT_PAGER=cat jj log -r "${BASE}::${TIP}" --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
PAGER=cat GIT_PAGER=cat jj diff --from "$BASE" --to "$TIP" --stat
PAGER=cat GIT_PAGER=cat jj bookmark list -r "${BASE}::${TIP} | ${TIP}"
```

Echo `OP` before any rewrite.

**Typecheck TIP now** (disposable child, same as §4) unless the trigger already said skip. Discover the command (`pnpm typefast`, `cargo check`, …). Fail → **no-go**: do not squash. Put that in **FEEDBACK NEEDED**: fix TIP first, or **skip typecheck** for this run. Pass → continue the questions.

Then **FEEDBACK NEEDED** (indexed). Do not squash until answered. Skip a question only if the trigger already answered it.

1. **Scope:** squash the whole stack onto trunk (`main` / `main@origin` as `BASE`, `TIP=@`)? or **only `@`** (one rev vs its parent)?
2. **Slice count:** how many revs, or **yolo** (agent picks from diff size, ~1 rev per ~1k lines, FE/BE split when reviewable alone, then shows the plan)?
3. **Bookmarks:** a local bookmark on **every** peeled rev (`stack/${TOPIC}/1-…`), or **tip only**?
4. **Typecheck:** already run on TIP. Confirm skip vs must-pass on every peeled rev (typecheck + **added** specs in that rev).

Propose the indexed plan with **approx line counts** per slice. Also list the **current** stack as notes (id + subject + size). Peels use the **final** tree: those messages will not come back, and one file cannot be “retry later” if the tip already has the later code.

```bash
# current stack (notes only)
PAGER=cat GIT_PAGER=cat jj log -r "${BASE}::${TIP}" --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
# per old rev:
PAGER=cat GIT_PAGER=cat jj diff -r <rev> --stat
# per proposed peel (paths that slice will take):
PAGER=cat GIT_PAGER=cat jj diff --from "$BASE" --to "$TIP" --stat -- path1 path2
```

Prefer separate FE/BE revs when either side is reviewable alone. Combine only when incoherent without both. Backend below frontend when the UI depends on the API.

Show the progress block (`step 1/5 inventory+preflight`). Wait.

## 2. Build one squash blob (restore onto BASE)

Avoid fragile “squash this revset” one-liners. Reproduce tip’s tree as **one** change on `BASE`. Keep `TIP` as the original change id (the old stack stays until the user agrees to abandon it):

```bash
jj new "$BASE" -m "$(cat <<'EOF'
wip: squash blob before resplit

EOF
)"
jj restore --from "$TIP" --into @
```

If `@` is conflicted after restore: **stop, use `jj-solve-conflict`**. Do not peel, do not hand-merge.

```bash
jj describe -m "$(cat <<EOF
wip: squash blob ${TOPIC}

EOF
)"
BLOB=@   # remember this change id; peels squash --from it
```

`@` is now a single revision vs `BASE` with the full tip tree. The old stack stays reachable via `$TIP`. Show progress (`step 2/5 blob-on-BASE`).

## 3. Peel path slices

Stay on the new stack. Do **not** `jj edit` the blob. Before each peel, print the progress block (`step 3/5 peel`, leftover count, this slice’s paths).

```bash
jj new "$BASE" -m "$(cat <<'EOF'
feat(scope): first slice why

EOF
)"
jj squash --from "$BLOB" --into @ --use-destination-message -- path/to/backend path/to/backend-tests
bash ~/.agents/skills/jj-resplit-stack/scripts/inventory.sh "$BASE" "$BLOB"

jj new -m "$(cat <<'EOF'
feat(scope): ui slice why

EOF
)"
jj squash --from "$BLOB" --into @ --use-destination-message -- path/to/frontend path/to/frontend-tests
bash ~/.agents/skills/jj-resplit-stack/scripts/inventory.sh "$BASE" "$BLOB"
# repeat until leftover is empty
```

`--use-destination-message` keeps the `-m` from `jj new` (destination = `@`). Without it, jj may open an editor to combine with `wip: squash blob`.

If a peel squash is conflicted: **stop, use `jj-solve-conflict`**.

**Tests travel with code.** If a test file spans two features, keep it with the dominant feature or split the file in a dedicated follow-up rev.

When leftover is empty: if `$BLOB` now **is** BASE, do **not** `jj abandon` it. Otherwise `jj abandon "$BLOB"` for the emptied leftover only.

## 4. Verify tests **per rev**

Unless the user skipped typecheck: every peeled rev must **typecheck**, and must run the **specs that rev adds**. A slice with no new tests: typecheck only. Discover commands from the project (`pnpm typefast`, `pnpm test --run path`, …). Do not assume a layout. Show progress (`step 4/5 tests`) before and after each rev.

**Safe (preferred) — disposable child** (tree equals parent `R`; abandon when done):

```bash
export PAGER=cat GIT_PAGER=cat
R=<slice-change>
jj log -r "$R" --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
jj diff -r "$R" --summary
jj new "$R" -m "$(cat <<'EOF'
tmp: test R

EOF
)"
# run focused tests for paths in R
jj abandon -r @
# @ is now a new empty untitled rev on the parent. Do not peel from it.
# Next slice: `jj new $NEXT`. Done testing: `jj edit $STACK_TIP`.
# If an empty no-description child of the new stack remains, `jj abandon` that change only.
```

**Safe — separate workspace** (long runs):

```bash
jj workspace add --name "test-${TOPIC}-R" -r "$R" /tmp/jj-test-${TOPIC}-R -m "$(cat <<'EOF'
tmp: test workspace

EOF
)"
( cd /tmp/jj-test-${TOPIC}-R && <test command> ); ec=$?
jj workspace forget "test-${TOPIC}-R"
```

On failure: fix in that rev (`jj edit R` or fix + squash-into with `--use-destination-message`), re-test, then continue. Do not finish with failing revs.

## 5. Deliverable (local only)

Restore `@` to the stack tip (abandon leftover test WCs first):

```bash
export PAGER=cat GIT_PAGER=cat
jj edit "$STACK_TIP"     # or: jj new "$STACK_TIP"
jj log -r "${BASE}::@" --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
# tip-only (default unless user asked per-rev):
jj bookmark set "stack/${TOPIC}" -r "$STACK_TIP"
# per-rev (only if user asked):
jj bookmark set "stack/${TOPIC}/1-<slug>" -r <rev1>
jj bookmark set "stack/${TOPIC}/2-<slug>" -r <rev2>
```

Do **not** `jj bookmark set` an existing PR bookmark (`push-*`, `@git`). Under **FEEDBACK NEEDED**, ask whether to point it at the new tip. Wait. Do not move it in this turn.

Report: ordered revs (message, paths, test command + pass), `OP`, suggested stacked PR titles. **Do not** push or open PRs unless the user explicitly asks later.

After the new stack is verified, ask before abandoning the old pre-squash range (still pointed at by `$TIP`).

Closing message **must** include the rollback command with the real `OP` from step 1:

```bash
jj op restore $OP
```

## Git fallback (no `jj root`)

Still **no push**. Capture `HEAD=$(git rev-parse HEAD)` first, echo it, and print `git reset --hard $HEAD` at the end (only if something hard-broke; confirm first). Confirm before any destructive reset.

No duplicate/auto-rebase — tell the user jj would have been better.

## Anti-patterns

- Creating backup bookmarks or `jj duplicate` snapshots “to be safe”
- Skipping the opening `OP=` echo or the closing `jj op restore $OP`
- Bare `jj squash` (opens an editor) / peeling without `--use-destination-message`
- Forcing FE+BE into one rev when they were separable
- Squashing before preflight answers (scope, N/yolo, bookmarks, typecheck skip vs no-go)
- Testing only the tip / skipping TIP typecheck when it failed
- Creating per-rev bookmarks when the user asked tip-only
- `jj abandon` BASE when leftover inventory says TO is BASE
- Leaving empty untitled `@` after abandoning a test child
- Dumping `jj log mutable()` or the full bookmark list
- Silently `jj bookmark set` a PR bookmark (`push-*`)
- Dirtying feature revs via careless `jj run`
- Inlining conflict resolution (use `jj-solve-conflict`)
- Using this skill for day-to-day describe/absorb (use `jj-auto-revise`)
- Bare `jj status` / `jj log` / `jj diff` / `jj help` / `jj bookmark list` on an agent PTY (hangs in `less`)
- Pushing stack bookmarks
- Hand-symlinking this skill into `~/.agents/skills` (Home Manager owns that path)
