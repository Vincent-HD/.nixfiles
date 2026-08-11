---
name: jj-resplit-stack
description: >
  Squash a messy jj (or git) stack, backup the blob, then resplit into meaningful revisions for a
  stacked PR — by feature, preferring frontend/backend separation when possible, with related tests
  in each rev and tests run successfully per rev. Use when the user asks to resplit, squash and
  split, prepare stacked PRs, clean wip history, or reorganize commits by feature before review.
---

# jj resplit stack

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds.

**Never** `git push`, `jj git push`, or any remote push. Local bookmarks only.

Companion for day-to-day revise-as-you-go: `jj-auto-revise`.

## Goal

1. Split by **feature** (or one large coherent change).
2. Prefer **frontend vs backend** (or app vs library) **per feature when possible**.
3. Keep **related tests with the code** they cover.
4. **Run tests successfully for each resulting rev** before done.
5. **Backup before squash and again after squash** (well-named local bookmarks; optional `jj duplicate`).

## Hard rules

- No push (not even “backup to origin”).
- Prefer filesets / explicit `--from`/`--into` over interactive `-i`.
- Do not amend test output, logs, or build junk into feature revs.
- Large or ambiguous stacks → propose a plan under **FEEDBACK NEEDED** and wait before squash.

## Workflow

### 0. Inventory

```bash
jj root
jj status
jj log -r 'mutable()' -n 40
jj bookmark list
```

Pick `BASE` (trunk / `main` / stack root) and confirm tip `@`.

### 1. Propose split plan

Indexed plan, for example:

1. `feat(api): …` — backend + its tests  
2. `feat(ui): …` — frontend + its tests  
3. `docs: …`

Prefer separate FE/BE revs when either side is reviewable alone. Combine only when the change is incoherent without both. Put the plan in **FEEDBACK NEEDED** when cut points are unclear; wait for confirmation.

### 2. Backup **before** squash (mandatory)

```bash
STAMP=$(date +%Y%m%d-%H%M)
TOPIC=my-topic

jj bookmark create "backup/pre-squash-${TOPIC}-${STAMP}" -r @
# Optional content copy (sibling); pin whatever change id jj log shows for the duplicate:
jj duplicate "backup/pre-squash-${TOPIC}-${STAMP}"
jj bookmark create "backup/pre-squash-${TOPIC}-${STAMP}-dup" -r <duplicate-change-id>
```

Report bookmark names and change/commit ids in the reply (`jj op restore` safety net).

### 3. Build one squash blob (preferred: restore onto BASE)

Avoid fragile “squash this revset” one-liners. Reproduce tip’s tree as **one** change on `BASE`:

```bash
PRE="backup/pre-squash-${TOPIC}-${STAMP}"

jj new "$BASE" -m "$(cat <<'EOF'
wip: squash blob before resplit

EOF
)"
jj restore --from "$PRE" --into @
jj describe -m "$(cat <<EOF
wip: squash blob ${TOPIC} ${STAMP}

EOF
)"
```

`@` is now a single revision vs `BASE` with the full tip tree. Leave the old stack reachable via `$PRE` until the new stack is verified.

### 4. Backup **after** squash (mandatory)

```bash
jj bookmark create "backup/post-squash-${TOPIC}-${STAMP}" -r @
BLOB=$(jj log -r @ -T 'change_id' --no-graph)
jj bookmark create "backup/blob-${TOPIC}-${STAMP}" -r "$BLOB"
```

Do not abandon or rewrite backup bookmarks while resplitting.

### 5. Resplit into meaningful revs

Pin `BLOB`, then peel path slices onto a new stack from `BASE`:

```bash
BLOB="backup/blob-${TOPIC}-${STAMP}"

jj new "$BASE" -m "$(cat <<'EOF'
feat(scope): first slice why

EOF
)"
jj squash --from "$BLOB" --into @ path/to/backend path/to/backend-tests

jj new -m "$(cat <<'EOF'
feat(scope): ui slice why

EOF
)"
jj squash --from "$BLOB" --into @ path/to/frontend path/to/frontend-tests
# repeat until BLOB has nothing useful left; abandon emptied blob only after backups exist
```

Alternatives: repeated `jj split path/a path/b` on the blob; or `jj restore --from "$BLOB" --into @ -- paths` when composing a slice on `BASE` (do not double-apply the same paths).

**Tests travel with code.** If a test file spans two features, keep it with the dominant feature or split the file in a dedicated follow-up rev.

**FE/BE:** separable → two stacked revs (backend below frontend when the UI depends on API). Shared contract that must land together → one rev or tight adjacent pair.

### 6. Verify tests **per rev**

Discover the project’s own test command from its docs/`package.json`/`Makefile`/`cargo`, etc. Do not assume a layout.

**Safe (preferred) — disposable child** (tree equals parent `R`; abandon when done):

```bash
jj new R -m "tmp: test R"
# run focused tests for paths in R
jj abandon -r @
jj edit <stack-tip>
```

**Safe — separate workspace** (long runs):

```bash
jj workspace add --name "test-${TOPIC}-R" -r R /tmp/jj-test-${TOPIC}-R
( cd /tmp/jj-test-${TOPIC}-R && <test command> ); ec=$?
jj workspace forget "test-${TOPIC}-R"
```

**Avoid** bare `jj run -r R -- <test>`: it checks out, runs, and **amends** each revision with the resulting WC. Only use it if the command cannot dirty the tree (or you restore the tree and still propagate the exit code). Prefer the patterns above.

On failure: fix in that rev (`jj edit R` or fix rev + squash-into), re-test, then continue. Do not finish with failing revs.

### 7. Deliverable (local only)

```bash
jj log -r "${BASE}::@"
jj bookmark set "stack/${TOPIC}/1-<slug>" -r <rev1>
jj bookmark set "stack/${TOPIC}/2-<slug>" -r <rev2>
```

Report: ordered revs (message, paths, test command + pass), backup bookmark names/ids, suggested stacked PR titles. **Do not** push or open PRs unless the user explicitly asks later.

After the new stack is verified, ask before abandoning the old pre-squash range (still pointed at by `$PRE`).

## Git fallback (no jj)

Still **no push**.

```bash
git branch "backup/pre-squash-${TOPIC}-${STAMP}"
# soft-reset / path commits only with user OK
git branch "backup/post-resplit-${TOPIC}-${STAMP}"
```

Backup branch first is mandatory. Confirm before destructive reset.

## Anti-patterns

- Squash without pre- **and** post-squash backups
- Forcing FE+BE into one rev when they were separable
- Testing only the tip
- Dirtying feature revs via careless `jj run`
- Pushing backup or stack bookmarks
- Hand-symlinking into `~/.agents/skills` (Home Manager owns that path)
