---
name: jj-resplit-stack
description: >
  Squash a messy jj (or git) stack, backup the blob, then resplit into meaningful revisions for a
  stacked PR — by feature, preferring frontend/backend separation when possible, with related tests
  in each rev and tests run successfully per rev. Keeps a running progress block (BASE, leftover
  files, backups, tests). Use when the user asks to resplit, squash and split, prepare stacked PRs,
  clean wip history, or reorganize commits by feature before review.
---

# jj resplit stack

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companions: day-to-day describe/absorb → `jj-auto-revise` (this skill is the later cleanup). Conflicted restore/peel → `jj-solve-conflict` (stop; do not resolve here).

This skill only **backups → squash blob onto BASE → peels feature/FE-BE slices → tests each rev**. It does not run the prompt-boundary revise loop and does not resolve conflicts.

## Hard rules

- Backup **before** squash and **again** after the blob exists. Do not abandon backup bookmarks.
- Duplicate the **range** `BASE..TIP` (not only the tip). Bookmarks on a rewritten change **follow**; abandoning a commit **deletes** its bookmarks. The duplicate is the real snapshot.
- Squash peels with `--use-destination-message` so the blob's `wip: squash blob` text does not overwrite the slice `-m`, and so nano never opens.
- No interactive `-i`. No push. No `jj op restore` unless the user asks or a backup is the only way out — then report the op id first.
- Tests travel with the code they cover. Prefer FE/BE split when either side is reviewable alone.
- Never bare `jj run -r R -- <test>`: it checks out, runs, and **amends** R. Use a disposable child or a workspace.
- After the new stack is verified: restore `@` to the stack tip. Ask before abandoning the old pre-squash range. **Do not delete backups yourself.**

## Progress (mandatory)

Every user-visible message while this skill runs includes a **progress block**. Do not wait until the end. Update it after inventory, after backups, before each peel, and after each test.

```markdown
**Resplit:** step 3/7 blob-on-BASE
**BASE:** `main` (`change_id`)  **TIP/PRE:** ...
**Plan:** 1 backend 2 frontend 3 docs  (N remaining slices)
**Now:** peeling slice 2/3 — `feat(ui): …` — paths: apps/frontend …
**Blob leftover:** M files  (or “empty, abandon blob”)
**Tests:** rev1 pass / rev2 running / …
**Backups:** pre-squash-…  dup=…  blob=…  op=…
```

Steps: `1 inventory+plan` · `2 pre-backup` · `3 blob-on-BASE` · `4 post-backup` · `5 peel` · `6 tests` · `7 deliver`.

Extra recipes: [reference.md](reference.md).

## 1. Inventory + plan

```bash
jj root
jj status
BASE=main   # trunk / stack root — not the first wip commit
TIP=@
# optional helper (same directory as this skill):
#   bash ~/.agents/skills/jj-resplit-stack/scripts/inventory.sh "$BASE" "$TIP"

jj log -r 'mutable()' -n 40 --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
jj log -r "${BASE}::${TIP}" --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
jj diff --from "$BASE" --to "$TIP" --summary
jj bookmark list
```

Pick `BASE` and `TIP`. If several heads or `BASE` is unclear: list them indexed under **FEEDBACK NEEDED** and wait.

Propose an indexed split plan, for example:

1. `feat(api): …` — backend + its tests
2. `feat(ui): …` — frontend + its tests
3. `docs: …`

Prefer separate FE/BE revs when either side is reviewable alone. Combine only when the change is incoherent without both. Backend below frontend when the UI depends on the API.

Put the plan in **FEEDBACK NEEDED** when cut points are unclear; wait before squash. Show the progress block (`step 1/7 inventory+plan`, leftover = tip-vs-BASE file count).

If the user only wanted day-to-day describe/absorb: use `jj-auto-revise`. Stop.

## 2. Backup **before** squash (mandatory)

```bash
STAMP=$(date +%Y%m%d-%H%M)
TOPIC=${TOPIC:-resplit}
OP=$(jj op log -n 1 -T 'self.id().short()' --no-graph)
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

When leftover is empty: abandon the emptied blob only after backups exist (`jj abandon "$BLOB"`). Do not abandon the `-dup`.

## 6. Verify tests **per rev**

Discover the project’s own test command from its docs/`package.json`/`Makefile`/`cargo`, etc. Do not assume a layout. Show progress (`step 6/7 tests`) before and after each rev.

**Safe (preferred) — disposable child** (tree equals parent `R`; abandon when done):

```bash
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
jj edit "$STACK_TIP"     # or: jj new "$STACK_TIP"
jj log -r "${BASE}::@" --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
jj bookmark set "stack/${TOPIC}/1-<slug>" -r <rev1>
jj bookmark set "stack/${TOPIC}/2-<slug>" -r <rev2>
```

Report: ordered revs (message, paths, test command + pass), backup bookmark names/ids, `OP`, suggested stacked PR titles. **Do not** push or open PRs unless the user explicitly asks later.

After the new stack is verified, ask before abandoning the old pre-squash range (still pointed at by `$PRE`).

**Do not delete backups yourself.** In the closing message, give the user copy-paste commands (real names from steps 2 and 4). The duplicate is the real snapshot (different change id). The non-`dup` bookmark often follows the rewritten live change — deleting it only drops the name (and vanishes on its own if that commit is abandoned).

```bash
# drop backup names (safe; live/new stack stays)
jj bookmark delete \
  backup/pre-squash-${TOPIC}-${STAMP} \
  backup/pre-squash-${TOPIC}-${STAMP}-dup \
  backup/blob-${TOPIC}-${STAMP} \
  backup/blob-${TOPIC}-${STAMP}-dup \
  backup/post-squash-${TOPIC}-${STAMP}

# also drop the duplicated sibling stack + frozen blob (the actual copies)
jj abandon <pre-squash-dup-range>     # change ids jj duplicate printed for BASE..TIP
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
- Testing only the tip
- Dirtying feature revs via careless `jj run`
- Inlining conflict resolution (use `jj-solve-conflict`)
- Using this skill for day-to-day describe/absorb (use `jj-auto-revise`)
- Deleting backup bookmarks/duplicates unless the user asked
- Pushing backup or stack bookmarks
- Hand-symlinking this skill into `~/.agents/skills` (Home Manager owns that path)
