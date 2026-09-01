# jj-resplit-stack reference

Official sources: [operation log](https://docs.jj-vcs.dev/latest/operation-log/), [bookmarks](https://docs.jj-vcs.dev/latest/bookmarks/). Do not run `jj help` in an agent shell (paginates).

**No pager.** Prefix every standalone `jj` with `PAGER=cat GIT_PAGER=cat`. Helper scripts set this themselves.

## Op restore

Capture before any rewrite. Echo in the first message. Print at the end. Do not restore unless the user asks.

```bash
OP=$(PAGER=cat GIT_PAGER=cat jj op log -n 1 -T 'self.id().short()' --no-graph)
echo "OP=$OP"
# closing:
jj op restore $OP
```

`jj undo` = last operation only. Do not create backup bookmarks or `jj duplicate` snapshots.

## Leftover files (blob vs BASE)

`$BLOB` is the **change id** of the squash-blob leftover (remembered after restore onto BASE). It is the peel source, not a backup.

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

Count 0 → progress **Blob leftover:** `empty`. If inventory says `TO is BASE`, do **not** `jj abandon` BASE. Otherwise `jj abandon "$BLOB"` for the emptied leftover only.

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

Ask before `jj abandon` of the old pre-squash range (`$TIP`). Closing message always includes `jj op restore $OP`.

## Commands cheat sheet

```bash
jj restore --from "$TIP" --into @
jj squash --from "$BLOB" --into @ --use-destination-message -- paths

jj bookmark set NAME -r REV
jj abandon REVSET

jj workspace add --name NAME -r R DEST
jj workspace forget NAME

jj diff --from "$BASE" --to "$BLOB" --summary
jj op log -n 1 -T 'self.id().short()' --no-graph
jj op restore OP
```

## Out of scope (other skills)

| Need | Skill |
| ---- | ----- |
| Prompt-boundary describe / absorb into ancestor | `jj-auto-revise` |
| Conflict markers, `:ours`/`:theirs`, lockfile merge | `jj-solve-conflict` |
