---
name: jj-auto-revise
description: >
  Continuously keep implementation work as meaningful Jujutsu revisions, preferring jj absorb /
  squash-into over blind new commits for follow-ups to recent revs. Use when finishing a logical
  chunk, the user says "jj", "absorb", "describe", "split revisions", "as usual with jj", or when
  deciding whether a change needs a new rev vs folding into an ancestor.
---

# jj auto-revise

Repo-agnostic personal skill. Prefer **jj** when `jj root` succeeds; otherwise use the short git fallback.

**Never** `git push`, `jj git push`, or any remote push.

Companion for later squash→resplit into a stacked PR: `jj-resplit-stack`.

## Goal

Keep history meaningful **while coding**, without a new revision for every tiny follow-up.

| Situation | Action |
| --------- | ------ |
| New logical concern | Finalize current rev (`jj describe`), then `jj new` |
| Same concern as `@` | Keep editing `@`; refine message with `jj describe` if needed |
| Small follow-up to a **recent mutable ancestor** (same lines/files) | Prefer `jj absorb` |
| Same concern as a **known** ancestor; absorb ambiguous | `jj squash --from @ --into <rev> [paths…]` |
| WC mashed unrelated topics | `jj split <filesets…>` (non-interactive), describe each side |
| Empty accidental `wip` | `jj abandon <rev>` |

## Decision tree

1. One sentence: what is this change about? If it does not match `@`’s description → do not mash.
2. Follow-up to mutable history?
   - Same hunks/files as a recent rev → **`jj absorb`** first.
   - Clear target, absorb won’t place it → **`jj squash --from @ --into <rev>`** (path-limit if needed).
3. New concern → **`jj describe`** then **`jj new`**.
4. Mixed `@` → **`jj split`** by fileset; never overwrite a good message with a kitchen-sink describe.
5. After absorb/squash → verify with **`jj op show -p`** and/or `jj log` + `jj diff -r <rev>`.

### Meaningful vs noise

Separate rev only when the unit is reviewable alone (feature, fix, refactor, test-only, docs). Fold into an ancestor (absorb / squash-into):

- typo / import / comment on the change you just described
- docs that only document that same change
- test fix for an assertion introduced in `@` or a recent ancestor of the same concern

## Command cookbook

```bash
jj root
jj status
jj log -n 15
jj diff -r @
jj op show -p

jj describe -m "$(cat <<'EOF'
feat(scope): why this change exists

EOF
)"

jj new

jj absorb
jj absorb path/to/file path/to/dir
jj absorb -f @ -t 'mutable()'

jj squash --from @ --into <rev> -m "$(cat <<'EOF'
feat(scope): updated why

EOF
)"
jj squash --from @ --into <rev> path/a path/b

# Selected filesets stay in the original rev; remainder becomes a new child
jj split path/a path/b -m "$(cat <<'EOF'
fix(scope): first slice why

EOF
)"
# then jj describe the remaining child (@)

jj abandon <rev>

# Local bookmarks only
jj bookmark set my-topic -r @
```

### Notes

- **Absorb:** moves hunks into the closest mutable ancestor that last touched those lines; ambiguous hunks stay in source.
- **Split:** prefer filesets; avoid `-i` when paths suffice. Selected → first rev; remainder → child.
- **Squash:** bare `jj squash` folds into the parent — often wrong for “follow-up to `@--`”. Prefer explicit `--from` / `--into`.

## Git fallback (no jj)

Still **no push**. Same concern as HEAD → amend only if user rules allow (yours, not pushed). Else new path-staged commit. No absorb equivalent.

## Anti-patterns

- New rev per drive-by lint on the feature you just described
- Describing a mixed WC with a message that covers half the diff
- Squashing into parent by habit when absorb would target the correct ancestor
- Any push / force-push
- Interactive `jj split -i` / `jj squash -i` when filesets suffice
