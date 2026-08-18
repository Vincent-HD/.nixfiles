# jj-solve-conflict reference

Official sources: [conflicts](https://docs.jj-vcs.dev/latest/conflicts/), [working copy](https://docs.jj-vcs.dev/latest/working-copy/), [tutorial rebase](https://docs.jj-vcs.dev/latest/tutorial/), [operation log](https://docs.jj-vcs.dev/latest/operation-log/). Do not run `jj help` in an agent shell (paginates).

**No pager.** Prefix every standalone `jj` with `PAGER=cat GIT_PAGER=cat`. Helper scripts set this themselves.

## Why jj is different

A conflicted rebase **already succeeded**. Commits store a logical conflict, not nested markers. Rewriting an ancestor rebases descendants even while they are conflicted. Resolving commit B2 auto-rebases C; if C only needed B2's resolution, C becomes clean (git-rerere, by design).

No `git rebase --continue`. One loop for rebase, merge, duplicate, absorb: `jj new` → resolve → `jj squash`.

## Rebase that produced the conflicts

| Flag | What moves |
| ---- | ---------- |
| `-s/--source REV` | REV **and descendants** onto the destination |
| `-b/--branch REV` | the whole branch containing REV (default `-b @`) |
| `-r/--revisions REV` | those revs **without** taking descendants along |
| `-o/--onto` | new parent(s); existing descendants of destination stay |
| `-A/--insert-after` | splice in; destination's descendants rebase onto the moved revs |
| `-B/--insert-before` | moved revs become parents of the targets |

You usually resolve **after** this, not by re-running rebase.

## Marker styles

Materialized only in the working copy / diffs (`jj new`, `jj edit`, `jj show`). Config: `ui.conflict-marker-style` = `jj` (default, snapshot + diffs), `snapshot`, or `git` (diff3, 2-sided only).

Default jj style (2-sided rebase):

```
<<<<<<< dest-change dest-commit "msg" (rebase destination)
<destination / new parent bytes>
||||||| ancestor-change ancestor-commit "msg" (parents of rebased revision)
<merge-base bytes>
=======
<rebased revision bytes>
>>>>>>> ours-change ours-commit "msg" (rebased revision)
```

Some files wrap a shared `{` / prefix **outside** the markers. Reconstruct each side as `prefix + hunk + suffix` before parsing JSON/codegen.

`<<<<<<<` / `>>>>>>>` may be lengthened when the file already contains `=======`.

`:ours` = first side = destination. `:theirs` = second side = rebased rev.

## pnpm lockfile

If `pnpm-lock.yaml` is conflicted, do not 3-way it. Resolve conflicted `package.json` / `pnpm-workspace.yaml` first (pnpm cannot parse markers), then from that workspace root:

```bash
pnpm i
```

pnpm rewrites the lockfile. Squash that result into the conflicted rev. Same if the lockfile is the only conflicted file.

## Whole-file 3-way (JSON snapshots, codegen)

When the conflict is the entire file (three ~equal-sized hunks):

1. Parse dest, ancestor, ours.
2. For maps/tables: dest as base; add ours-only keys; for keys in both, if dest==ancestor take ours, if ours==ancestor take dest, else recurse or hand-merge.
3. **Write back in dest's original text format** (tabs vs spaces, key order, compact arrays). Splice table/object blobs into dest text. Do not pretty-print from a serializer unless dest already used that exact style.

If you already pretty-printed by mistake: squash a formatting fix into the **first** resolved rev before continuing. Otherwise every later commit is a whole-file conflict.

## Evolog (pre-rebase bytes)

```bash
jj evolog -r CHANGE -n 20
# CHANGE/4 often the last non-conflict version before the rebase op
jj file show -r CHANGE/4 path
```

Use this to check that a `:ours` take did not drop additions the pre-rebase tip still had.

## Useful revsets / templates

```bash
conflicts()
roots(conflicts())
roots(conflicts() & somebookmark::)
conflicts() & somebookmark::

jj log -r REV -T 'conflicted_files.map(|e| e.path().display()).join(",") ++ "\n"'
```

`conflicts()` is “files in a conflicted state”, not bookmark conflicts.

## Commands cheat sheet

```bash
jj resolve --list -r REV
jj resolve --tool :ours path
jj resolve --tool :theirs path
# external 3-way (2-sided + base only):
jj resolve --tool meld path

jj restore --from REV --into @ -- path
jj file show -r REV path

jj squash --from @ --into REV --use-destination-message

jj next --conflict          # after current is clean
jj undo                     # last operation only
jj op log -n 5 --no-graph
jj op restore OP            # last resort; report OP from backup step

jj duplicate TIP            # sibling copy on same parents
jj bookmark create NAME -r REV
jj bookmark rename OLD NEW
jj bookmark delete NAME [NAME...]
jj abandon DUP_TIP          # drop the duplicate snapshot after the user asks
```

`jj restore` without `--from` restores `@` from its parent (throws away WC edits).

## Drop backups (user-requested only)

```bash
jj bookmark delete backup/pre-resolve-TOPIC-STAMP backup/pre-resolve-TOPIC-STAMP-dup
jj abandon DUP_TIP
```

Do not run this unless the user asked. The non-`dup` bookmark may have followed the live rewritten tip.

## Workspaces (long / parallel)

Rarely needed. `jj workspace add --name resolve-A -r FIRST /tmp/jj-resolve-A` gives a second WC on the first conflict. Forget the workspace when done. Do not run two writers on the same change ids.

## Bookmark vs file vs divergent

| Kind | Where | This skill |
| ---- | ----- | ---------- |
| File conflict | `jj status`, red `(conflict)` on a commit | yes |
| Bookmark conflict | `jj bookmark list` after fetch | no, unless asked |
| Divergent change | same change id, two commits | no (`jj abandon` / `jj rebase` one side) |

## Upstream limits

Directory / file / symlink conflicts: restore one side; there is no good 3-way (jj#19).
