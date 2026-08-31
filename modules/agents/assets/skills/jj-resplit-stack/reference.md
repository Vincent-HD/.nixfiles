# jj-resplit-stack reference

Official sources: [operation log](https://docs.jj-vcs.dev/latest/operation-log/), [bookmarks](https://docs.jj-vcs.dev/latest/bookmarks/). Do not run `jj help` in an agent shell (paginates).

**No pager.** Prefix every standalone `jj` with `PAGER=cat GIT_PAGER=cat`. Helper scripts set this themselves.

## Why `jj duplicate 'BASE..TIP'` (not tip-only)

`x..y` = ancestors of `y` excluding ancestors of `x` (includes TIP, excludes BASE). BASE must be trunk (`main` / immutable head), not the first wip commit.

`jj duplicate` without `--onto` / `-A` / `-B` copies onto **existing parents** (or onto other newly duplicated commits). That yields a sibling stack:

- first stack commit (parent = BASE) → copy also parented on BASE
- the rest chain onto the new copies

A **tip-only** `jj duplicate $TIP` copies TIP onto its **live parent**. Abandoning or rewriting that parent rebases the copy. The range duplicate does not.

Output (oldest first). Pin the **last** `Duplicated … as CHANGE` line — that is the copy of TIP:

```
Duplicated <old-commit> as <new-change> <new-commit> <description>
```

`--onto` / `-A` / `-B` change the destination. Do not use them for this backup; we want a sibling, not a splice.

Bookmarks **follow** rewritten change ids. When a commit is **abandoned**, jj **deletes** bookmarks on it. Non-`dup` names on the live blob/tip are labels, not snapshots.

## Leftover files (blob vs BASE)

```bash
bash ~/.agents/skills/jj-resplit-stack/scripts/inventory.sh "$BASE" "$BLOB"
# same thing by hand:
export PAGER=cat GIT_PAGER=cat
jj diff --from "$BASE" --to "$BLOB" --summary
jj diff --from "$BASE" --to "$BLOB" --summary | wc -l
```

When `@` **is** the leftover blob (do not do this during peels):

```bash
export PAGER=cat GIT_PAGER=cat
jj diff --from "$BASE" --summary
```

`jj file list -r "$BLOB"` lists the **whole tree**, not the delta. Use `--summary` for peel leftovers.

Count 0 → progress **Blob leftover:** `empty`. If inventory says `TO is BASE`, **delete the leftover bookmark name** — do not `jj abandon` BASE. Otherwise `jj abandon "$BLOB"` only after `-dup` backups exist.

To inspect an emptied blob before abandoning, squash the last paths with `--keep-emptied`, inventory, then abandon.

## Peel mechanics

```bash
jj new "$BASE" -m "$(cat <<'EOF'
feat(scope): why

EOF
)"
jj squash --from "$BLOB" --into @ --use-destination-message -- path1 path2
```

Destination = `@` = the new described slice. `--use-destination-message` keeps that `-m` and discards `wip: squash blob`. `-m HEREDOC` / `--use-destination-message` so the editor never opens.

Do not double-apply the same paths. Alternatives (pick one per slice):

- `jj squash --from "$BLOB" --into @ --use-destination-message -- paths` (preferred)
- `jj restore --from "$BLOB" --into @ -- paths` then remove those paths from the blob with a later squash, or
- `jj split` on the blob (`-i` forbidden; split by explicit paths only)

Deleted paths: pass them on `jj squash -- -- path`. `No matching entries` on empty `@` is OK if leftover inventory then drops those `D`s.

Stay on the new stack. `jj squash --from "$BLOB"` does not require checking out the blob.

If restore or squash reports a conflict: stop; `jj-solve-conflict`.

## Log templates (`--no-graph`)

```bash
export PAGER=cat GIT_PAGER=cat
jj op log -n 1 -T 'self.id().short()' --no-graph

jj log -r @ --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ if(empty, "(empty) ", "") ++ description.first_line() ++ "\n"'

jj log -r "${BASE}::${TIP}" --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'

jj log -r "${BASE}::@" --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'

# bookmarks on the stack only (do not dump the whole repo list)
jj bookmark list -r "${BASE}::${TIP} | ${TIP}"
```

## Tests per rev

Never `jj run -r R -- <test>`: jj checks out R, runs the command, **amends** R with the resulting WC.

Disposable child (preferred): `jj new R` → test → `jj abandon -r @`. That abandon leaves an empty untitled `@` on the parent — do not leave it; `jj new` the next slice or `jj edit $STACK_TIP`.

Workspace (long / parallel): `jj workspace add --name NAME -r R DEST`. Forget the workspace when done. Do not run two writers on the same change ids.

Fix failures in R (`jj edit R`, or squash-into R with `--use-destination-message`), re-test, continue.

## Restore WC when done

```bash
jj abandon <empty leftover test WCs>
jj edit "$STACK_TIP"     # or: jj new "$STACK_TIP"
```

Do not `jj describe` an empty leftover test `@`.

## Drop backups (user-requested only)

Copy-paste with a comment on every name (old live stack vs sibling snapshot vs leftover blob vs frozen blob). Do not run unless the user asked.

```bash
# old live tip from before squash (often already followed/gone)
jj bookmark delete backup/pre-squash-TOPIC-STAMP
# sibling copy of the old stack — the real snapshot
jj bookmark delete backup/pre-squash-TOPIC-STAMP-dup
# live leftover blob (follows peels; may point at BASE — name only, do not abandon)
jj bookmark delete backup/blob-TOPIC-STAMP
# frozen full-tree blob right after squash
jj bookmark delete backup/blob-TOPIC-STAMP-dup
jj bookmark delete backup/post-squash-TOPIC-STAMP

# sibling of BASE..TIP (old stack copy)
jj abandon <pre-squash-dup-range>
# frozen squash blob (not the new peeled stack)
jj abandon <blob-dup-tip>
```

Do not run this unless the user asked. The non-`dup` bookmark may have followed the live rewritten change (or already vanished when that commit was abandoned).

Old pre-squash **range** (`$PRE` / live stack): ask before `jj abandon`. Separate from dropping backup names.

`jj undo` = last operation only. `jj op restore OP` = last resort; report `OP` from the backup step first.

## Commands cheat sheet

```bash
jj duplicate "${BASE}..${TIP}"          # sibling stack; no --onto
jj duplicate @                          # blob snapshot after restore

jj restore --from "$PRE" --into @
jj squash --from "$BLOB" --into @ --use-destination-message -- paths

jj bookmark create NAME -r REV
jj bookmark set NAME -r REV
jj bookmark delete NAME [NAME...]
jj abandon REVSET

jj workspace add --name NAME -r R DEST
jj workspace forget NAME

jj diff --from "$BASE" --to "$BLOB" --summary
jj op log -n 1 -T 'self.id().short()' --no-graph
```

## Out of scope (other skills)

| Need | Skill |
| ---- | ----- |
| Prompt-boundary describe / absorb into ancestor | `jj-auto-revise` |
| Conflict markers, `:ours`/`:theirs`, lockfile merge | `jj-solve-conflict` |
