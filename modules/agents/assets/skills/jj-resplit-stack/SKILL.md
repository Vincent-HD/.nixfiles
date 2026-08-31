---
name: jj-resplit-stack
description: >
  Squash a messy jj (or git) stack or working copy, backup, then resplit into meaningful revisions.
  Always preflight: squash stack-onto-trunk vs only @; how many revs or yolo; bookmarks per rev vs
  tip-only; typecheck TIP first (fail = no-go unless skip). Then peel feature/FE-BE slices with
  tests per rev. Use when the user asks to resplit, squash and split, prepare stacked PRs, clean wip
  history, or reorganize commits by feature before review.
---

# jj resplit stack

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companions: day-to-day describe/absorb → `jj-auto-revise` (this skill is the later cleanup). Conflicted restore/peel → `jj-solve-conflict` (stop; do not resolve here).

This skill only **preflight → backups → squash blob onto BASE → peels feature/FE-BE slices → tests each rev**. It does not run the prompt-boundary revise loop and does not resolve conflicts.

## Hard rules

- **Wait on preflight** (section 1). Do not bookmark, duplicate, squash, or peel until the user answers. Answers in the trigger message count.
- Backup **before** squash and **again** after the blob exists. Do not abandon backup bookmarks. Never `jj abandon` a `backup/blob-*` that now points at BASE (delete the name only).
- Duplicate the **range** `BASE..TIP` (not only the tip). Bookmarks on a rewritten change **follow**; abandoning a commit **deletes** its bookmarks. The duplicate is the real snapshot.
- Squash peels with `--use-destination-message` so the blob's `wip: squash blob` text does not overwrite the slice `-m`, and so nano never opens.
- No interactive `-i`. No push. No `jj op restore` unless the user asks or a backup is the only way out — then report the op id first.
- No pager. Agent shells are PTYs: bare `jj status` / `jj log` / `jj diff` / `jj op *` / `jj help` / `jj bookmark list` open `less` and hang forever. Prefix **every** standalone `jj` with `PAGER=cat GIT_PAGER=cat`. Helper scripts already set this plus `ui.paginate=never`. Never `jj op show -p` unpiped.
- Tests travel with the code they cover. Prefer FE/BE split when either side is reviewable alone. Typecheck + added tests on **every** peeled rev unless the user skipped typecheck.
- Never bare `jj run -r R -- <test>`: it checks out, runs, and **amends** R. Use a disposable child or a workspace.
- After abandoning a test child, `@` is empty untitled — `jj new` the next slice or `jj edit $STACK_TIP`. Do not leave those empties on the stack.
- After the new stack is verified: restore `@` to the stack tip. Ask before abandoning the old pre-squash range. **Do not delete backups yourself.**
- Never `jj bookmark set` an existing PR bookmark (`push-*`, remote-tracking). **Ask only.**

## Progress (mandatory)

Every user-visible message while this skill runs includes a **progress block**. Do not wait until the end. Update it after inventory, after backups, before each peel, and after each test.

```markdown
**Resplit:** step 3/7 blob-on-BASE
**BASE:** `main` (`change_id`)  **TIP/PRE:** ...
**Plan:** 1 backend 2 frontend 3 docs  (N remaining slices)
**Now:** peeling slice 2/3 — `feat(ui): …` — paths: apps/frontend …
**Blob leftover:** M files  (or “empty, abandon blob”)
**Tests:** skip | TIP fail (no-go) | rev1 typecheck+specs / …
**Bookmarks:** per-rev | tip-only
**Backups:** pre-squash-…  dup=…  blob=…  op=…
```

Steps: `1 inventory+preflight` · `2 pre-backup` · `3 blob-on-BASE` · `4 post-backup` · `5 peel` · `6 tests` · `7 deliver`.

Extra recipes: [reference.md](reference.md).

## 1. Inventory + preflight (wait)

Read-only. If the user only wanted day-to-day describe/absorb: use `jj-auto-revise`. Stop.

```bash
PAGER=cat GIT_PAGER=cat jj root
# helper disables the pager itself:
#   bash ~/.agents/skills/jj-resplit-stack/scripts/inventory.sh "$BASE" "$TIP"

PAGER=cat GIT_PAGER=cat jj log -r "${BASE}::${TIP}" --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
PAGER=cat GIT_PAGER=cat jj diff --from "$BASE" --to "$TIP" --stat
PAGER=cat GIT_PAGER=cat jj bookmark list -r "${BASE}::${TIP} | ${TIP}"
```

Note the current op (`jj op log -n 1 -T 'self.id().short()' --no-graph`) for `jj op restore`.

**Typecheck TIP now** (disposable child, same as §6) unless the trigger already said skip. Discover the command (`pnpm typefast`, `cargo check`, …). Fail → **no-go**: do not backup/squash. Put that in **FEEDBACK NEEDED**: fix TIP first, or **skip typecheck** for this run. Pass → continue the questions.

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

Show the progress block (`step 1/7 inventory+preflight`). Wait.

## 2. Backup **before** squash (mandatory)

```bash
STAMP=$(date +%Y%m%d-%H%M)
TOPIC=${TOPIC:-resplit}
OP=$(PAGER=cat jj op log -n 1 -T 'self.id().short()' --no-graph)
PRE="backup/pre-squash-${TOPIC}-${STAMP}"

jj bookmark create "$PRE" -r "$TIP"

# sibling copy of the whole stack onto existing parents — the real snapshot
jj duplicate "${BASE}..${TIP}"
# pin the LAST "Duplicated … as CHANGE" line (copy of TIP):
jj bookmark create "${PRE}-dup" -r <duplicate-tip>
```

Why the range, not `jj duplicate $TIP`: a tip-only copy sits on the **live parent**. Rewriting or abandoning the stack body can still take it. `jj duplicate` without `--onto` copies onto existing parents (or onto other newly duplicated commits), so `BASE..TIP` is an independent sibling stack. Details: [reference.md](reference.md).

Report in the progress block: bookmark names, tip change/commit ids, `OP` (`jj op restore $OP` is the safety net). Do not push these bookmarks.

## 3. Build one squash blob (restore onto BASE)

Avoid fragile “squash this revset” one-liners. Reproduce tip’s tree as **one** change on `BASE`:

```bash
jj new "$BASE" -m "$(cat <<'EOF'
wip: squash blob before resplit

EOF
)"
jj restore --from "$PRE" --into @
```

If `@` is conflicted after restore: **stop, use `jj-solve-conflict`**. Do not peel, do not hand-merge.

```bash
jj describe -m "$(cat <<EOF
wip: squash blob ${TOPIC} ${STAMP}

EOF
)"
```

`@` is now a single revision vs `BASE` with the full tip tree. The old stack stays reachable via `$PRE` / `${PRE}-dup`. Show progress (`step 3/7 blob-on-BASE`).

## 4. Backup **after** squash (mandatory)

```bash
# live leftover blob — FOLLOWS peels; inventory this name
jj bookmark create "backup/blob-${TOPIC}-${STAMP}" -r @
BLOB="backup/blob-${TOPIC}-${STAMP}"

# frozen full-tree snapshot (real post-squash backup)
jj duplicate @
# pin the "Duplicated … as CHANGE" line:
jj bookmark create "backup/blob-${TOPIC}-${STAMP}-dup" -r <blob-dup>
jj bookmark create "backup/post-squash-${TOPIC}-${STAMP}" -r <blob-dup>
```

Do not abandon or rewrite backup bookmarks while resplitting. Live `backup/blob-*` will shrink as you peel; if the blob is later abandoned, jj **deletes** that live bookmark. The `-dup` keeps the full tree.

Show progress (`step 4/7 post-backup`). Leftover = `jj diff --from "$BASE" --to "$BLOB" --summary` (or the inventory script).

## 5. Peel path slices

Stay on the new stack. Do **not** `jj edit` the blob. Before each peel, print the progress block (`step 5/7 peel`, leftover count, this slice’s paths).

```bash
BLOB="backup/blob-${TOPIC}-${STAMP}"

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

When leftover is empty: if `backup/blob-*` now points at **BASE**, `jj bookmark delete` that name only — do **not** `jj abandon` it. Otherwise abandon the emptied blob only after `-dup` backups exist (`jj abandon "$BLOB"`). Do not abandon the `-dup`.

## 6. Verify tests **per rev**

Unless the user skipped typecheck: every peeled rev must **typecheck**, and must run the **specs that rev adds**. A slice with no new tests: typecheck only. Discover commands from the project (`pnpm typefast`, `pnpm test --run path`, …). Do not assume a layout. Show progress (`step 6/7 tests`) before and after each rev.

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

## 7. Deliverable (local only)

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

Report: ordered revs (message, paths, test command + pass), backup bookmark names/ids, `OP`, suggested stacked PR titles. **Do not** push or open PRs unless the user explicitly asks later.

After the new stack is verified, ask before abandoning the old pre-squash range (still pointed at by `$PRE`).

**Do not delete backups yourself.** In the closing message, give copy-paste with a **comment on every line** saying what that name is (old live stack, sibling snapshot, live leftover blob, frozen blob). Use the real names from this run.

```bash
# names only — does not delete the new stack
# old live tip from before squash (bookmark followed the rewritten change; often gone already)
jj bookmark delete backup/pre-squash-${TOPIC}-${STAMP}
# sibling copy of the old stack (real snapshot; keep until you abandon the range below)
jj bookmark delete backup/pre-squash-${TOPIC}-${STAMP}-dup
# live leftover blob (follows peels; may now point at BASE — delete the name, do not abandon)
jj bookmark delete backup/blob-${TOPIC}-${STAMP}
# frozen full-tree blob right after squash (same commit as post-squash)
jj bookmark delete backup/blob-${TOPIC}-${STAMP}-dup
jj bookmark delete backup/post-squash-${TOPIC}-${STAMP}

# drop the actual copies (different change ids from duplicate)
# sibling of BASE..TIP from step 2 (old stack, unused after resplit)
jj abandon <pre-squash-dup-range>
# frozen squash blob from step 4 (not the new peeled stack)
jj abandon <blob-dup-tip>
```

## Git fallback (no `jj root`)

Still **no push**. Backup branch first is mandatory. Confirm before destructive reset.

```bash
git branch "backup/pre-squash-${TOPIC}-${STAMP}"
# soft-reset / path commits only with user OK
git branch "backup/post-resplit-${TOPIC}-${STAMP}"
```

No duplicate/auto-rebase — tell the user jj would have been better.

## Anti-patterns

- Squash without pre- **and** post-squash backups (range duplicate + blob duplicate)
- Tip-only `jj duplicate $TIP` as the only snapshot
- Bare `jj squash` (opens an editor) / peeling without `--use-destination-message`
- Forcing FE+BE into one rev when they were separable
- Squashing before preflight answers (scope, N/yolo, bookmarks, typecheck skip vs no-go)
- Testing only the tip / skipping TIP typecheck when it failed
- Creating per-rev bookmarks when the user asked tip-only
- `jj abandon` on `backup/blob-*` after it followed to BASE
- Leaving empty untitled `@` after abandoning a test child
- Dumping `jj log mutable()` or the full bookmark list
- Silently `jj bookmark set` a PR bookmark (`push-*`)
- Dirtying feature revs via careless `jj run`
- Inlining conflict resolution (use `jj-solve-conflict`)
- Using this skill for day-to-day describe/absorb (use `jj-auto-revise`)
- Bare `jj status` / `jj log` / `jj diff` / `jj help` / `jj bookmark list` on an agent PTY (hangs in `less`)
- Deleting backup bookmarks/duplicates unless the user asked
- Pushing backup or stack bookmarks
- Hand-symlinking this skill into `~/.agents/skills` (Home Manager owns that path)
