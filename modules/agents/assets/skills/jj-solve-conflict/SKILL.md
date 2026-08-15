---
name: jj-solve-conflict
description: >
  Resolve Jujutsu (jj) conflicts after rebase, duplicate, absorb, or merge: backup first
  (bookmark + duplicate), teleport with jj new (not edit), resolve oldest-first, squash
  resolutions into the conflicted rev, and keep a running conflict count. Use when the
  user says "fix conflicts", "jj resolve", "unresolved conflicts", "rebase conflict",
  "conflicted commits", or jj hints to `jj new <rev>` then `jj squash`.
---

# jj solve conflict

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companions: day-to-day revise → `jj-auto-revise`. Later squash→resplit → `jj-resplit-stack`. This skill only **resolves conflicts**; it does not resplit or rewrite messages.

Official loop (jj docs + `jj rebase` hint): conflicts are first-class — the rebase already finished. There is no `--continue`. Check out the conflicted commit, resolve, amend via squash. Resolving an ancestor often auto-resolves descendants (rerere-by-design).

## Hard rules

- Backup **before** the first resolution. Do not abandon backup bookmarks.
- **Oldest conflict first** (`roots(conflicts() & SCOPE)`). Never start at the tip.
- Teleport with `jj new <conflicted>` (inspectable). Avoid `jj edit` on conflicted revs — official FAQ: harder to inspect the resolution (`jj diff` is the point of `new`).
- Squash with `--use-destination-message` so nano/the editor never opens.
- No interactive `-i`. No force-push. No `jj op restore` unless the user asks or a backup is the only way out — then report the op id first.
- Scope to **the user's stack**. Independent DAG roots (other feature bookmarks) stay conflicted unless the user included them.
- Preserve original file formatting. Reformatting a generated snapshot/lockfile turns every descendant into a whole-file 3-way.
- After the stack is clean: restore `@` to the original working-copy rev (or an empty child of the tip). Abandon leftover empty resolution WCs.

## Progress (mandatory)

Every user-visible message while this skill runs includes a **progress block**. Do not wait until the end. Update it after inventory, before tackling a conflict, and after each squash.

```markdown
**Conflicts:** N remaining · M files across K commits
**Stack:** <bookmark or change-id range>  (ignored: <other roots, if any>)
**Now:** tackling 1 / K — `<change_id>` `<first line>`
- files: `path` (2-sided) …
- what: <one line: union of tables / keep dest keys / take theirs deletion / …>
- plan: <jj new / resolve tactic / squash>
**Done:** D auto-resolved by last squash
```

When the same 1–2 files repeat across many commits, say so once (“48 commits, same snapshot hunk; oldest first, descendants may collapse”) instead of 48 identical plans.

**TLDR difficulties:** if something is surprising (whole-file JSON, `:ours` dropping later keys, mixed DAG roots, tree/file/symlink conflict), add a short `**TLDR:**` line in that same block. Record a papercut only for workflow friction, not for the conflict itself.

## 0. Inventory

```bash
jj root
jj status
HOME="$(jj root)"
# optional helper (same directory as this skill):
#   bash ~/.agents/skills/jj-solve-conflict/scripts/inventory.sh 'conflicts()'
```

Collect, then **show the progress block before editing files**:

```bash
# all conflicted commits (newest-first by default — reverse for oldest-first)
jj log -r 'conflicts()' --reversed --no-graph \
  -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'

# independent stacks
jj log -r 'roots(conflicts())' --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ " parents=" ++ parents.map(|c| c.change_id().short() ++ " " ++ c.description().first_line()).join(" | ") ++ "\n"'

# files in one rev
jj resolve -r REV --list
jj log -r REV -T 'conflicted_files.map(|e| e.path().display()).join("\n") ++ "\n"'
```

If `roots(conflicts())` has **more than one** lineage and the user did not name a stack: list each root (indexed) under **FEEDBACK NEEDED** and wait. Do not mix them.

Pick `SCOPE` (example: `mylxuvkm::` or `bookmark_name::`). Work only `conflicts() & SCOPE`.

Note the original WC: `ORIG=@` change id and its parent tip.

## 1. Backup (mandatory)

```bash
STAMP=$(date +%Y%m%d-%H%M)
TOPIC=${TOPIC:-conflicts}
TIP=$(jj log -r 'heads(SCOPE)' -T 'change_id.short()' --no-graph | head -1)
OP=$(jj op log -n 1 -T 'self.id().short()' --no-graph)

jj bookmark create "backup/pre-resolve-${TOPIC}-${STAMP}" -r "$TIP"

# content-identical sibling stack; survives rewriting the live stack
jj duplicate "backup/pre-resolve-${TOPIC}-${STAMP}"
# pin whatever change id `jj duplicate` printed for the duplicated tip:
jj bookmark create "backup/pre-resolve-${TOPIC}-${STAMP}-dup" -r <duplicate-tip>
```

Report in the progress block: bookmark names, tip change/commit ids, `OP` (`jj op restore $OP` is the safety net). Do not push these bookmarks.

## 2. Loop (oldest first)

```text
while conflicts remain in SCOPE:
  FIRST = roots(conflicts() & SCOPE)   # jj's own hint: `jj new <first>`
  tell the user the progress block for FIRST
  jj new FIRST -m "resolve conflicts"
  resolve files (section 3)
  jj diff                  # inspect resolution vs conflicted parent
  jj squash --from @ --into FIRST --use-destination-message
  recount: conflicts() & SCOPE
  note how many descendants jj just auto-resolved
```

Teleport extras:

| Goal | Command |
| ---- | ------- |
| Onto first conflict (preferred) | `jj new FIRST -m "resolve conflicts"` |
| Next conflicted descendant | `jj next --conflict` (only after the current one is clean) |
| Peek without becoming WC | `jj file show -r REV path` · `jj resolve -r REV --list` |
| Pre-rebase bytes | `jj evolog -r REV` then `jj file show -r REV/N path` |
| Restore WC when done | `jj edit ORIG` or `jj new TIP` |

`jj edit FIRST` is allowed only when `jj new` cannot represent the tree (rare). Say so in **TLDR**.

## 3. Resolve tactics

Inspect markers or `jj resolve --list` first. Then pick the **narrowest** tactic. Details: [reference.md](reference.md).

| Situation | Do |
| --------- | -- |
| Conflicted `pnpm-lock.yaml` (package lock) | **Easy:** do not merge it. Resolve any conflicted `package.json` / `pnpm-workspace.yaml` first, then `pnpm i`. pnpm regenerates the lockfile. Squash as usual. |
| Dest is a strict superset of the rebased side (same keys/tables plus extras) | `jj resolve --tool :ours path` then **verify** later commits did not add more of this file |
| Rebased commit **intentionally deleted** dest content | `:theirs` / keep the rebased side |
| Both sides **added different** content (tables, keys, functions) | **Union**. Do not take a whole side. |
| Generated snapshot / codegen (not the pnpm lock) | 3-way on **structure**; splice into dest **text** so indent/order stay dest's |
| True textual hunk (code you understand) | Edit markers, or `jj resolve --tool <merge-tool>` |
| “Take this file from rev R” | `jj restore --from R --into @ -- path` |
| Tree vs file vs symlink | No good 3-way yet (upstream #19). `jj restore` one side; **TLDR** it |
| Bookmark conflict (not file) | Out of scope unless the user asked; see `jj help -k glossary` |

`:ours` = conflict side **#1** = rebase **destination** (new parent). `:theirs` = side **#2** = **rebased revision**. Labels in markers (`<<<<<<< dest…` / `>>>>>>> rebased…`) beat memory.

After any whole-side take, diff the file against the **pre-rebase** tip (`evolog` `/N` before the rebase op). If the live tip lost additions, you took too much dest — union those additions back.

**pnpm lockfile:** if `pnpm-lock.yaml` is among the conflicted paths, skip markers / `:ours` / hand-merge. After other manifests in that WC are clean, run `pnpm i` from the lockfile's workspace root. Commit the regenerated lockfile via the same squash. Do not run `pnpm i` while `package.json` still has conflict markers.

**Generated files:** never `json.dumps(indent=2)` / formatter-rewrite the whole snapshot. Splice. If a first merge already reformatted the file, **rewrite that merge** (squash into the first conflicted rev) with original indentation before continuing — otherwise every descendant conflicts as a whole file.

## 4. Squash and recount

```bash
jj squash --from @ --into FIRST --use-destination-message
jj log -r 'conflicts() & SCOPE' --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' | wc -l
```

Expect: `Rebased N descendant commits` and `Existing conflicts were resolved or abandoned from K commits`. Update **Done:** with K. Repeat from step 2 until `conflicts() & SCOPE` is empty.

Leave other roots (`tlsxppxt::` etc.) as they are.

## 5. Verify + restore WC

```bash
# no markers on the tip
jj resolve -r TIP --list   # should fail or be empty
jj file show -r TIP path | rg '^(<<<<<<<|>>>>>>>|=======||||||||)($| )' || true

# restore where the user was
jj edit ORIG     # or: jj new TIP
jj abandon <empty leftover resolve WCs>
```

Do not `jj describe` an empty leftover `@`. Do not mash a codegen regen into an unrelated rev; if the tip's generated file is still wrong, put the fix on `@` described as that fix, or squash into the rev that owns the file.

Report backups, remaining foreign conflicts, and that nothing was pushed.

**Do not delete backups yourself.** In the closing message, give the user copy-paste commands (real names from step 1). The duplicate is the real snapshot (different change id). The non-`dup` bookmark often follows the rewritten live tip — deleting it only drops the name.

```bash
# drop backup names (safe; live stack stays)
jj bookmark delete backup/pre-resolve-${TOPIC}-${STAMP} backup/pre-resolve-${TOPIC}-${STAMP}-dup

# also drop the duplicated sibling commit (the actual copy)
jj abandon <duplicate-tip>
```

## Git fallback (no `jj root`)

Still **no push**. Backup branch, then the host's usual rebase/merge conflict loop. No duplicate/auto-rebase — tell the user jj would have been better.

## Anti-patterns

- Starting at the conflicted **tip** instead of `roots(conflicts() & SCOPE)`
- `jj edit` on a conflicted rev so you cannot `jj diff` the resolution
- Bare `jj squash` opening an editor
- `:ours` on a generated file without checking later commits still add to it
- Hand-merging `pnpm-lock.yaml` instead of `pnpm i`
- Reformatting a whole snapshot as the merge
- Deleting backup bookmarks/duplicates unless the user asked
- Resolving an unrelated second DAG root “while you're here”
- Pushing backup bookmarks
- `jj op restore` as the first reaction (undo only the last step with `jj undo` if the just-made squash is wrong)
- Hand-symlinking this skill into `~/.agents/skills` (Home Manager owns that path)
