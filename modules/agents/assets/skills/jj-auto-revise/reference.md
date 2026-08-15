# jj-auto-revise reference

Official: `jj help commit|describe|absorb|squash|split|abandon`, [working copy](https://docs.jj-vcs.dev/latest/working-copy/), [operation log](https://docs.jj-vcs.dev/latest/operation-log/).

This file is extra recipes. Day-to-day loop stays in [SKILL.md](SKILL.md). Conflicts → `jj-solve-conflict`. History resplit → `jj-resplit-stack`.

## Inspect templates

```bash
jj log -r @ --no-graph \
  -T 'change_id.short() ++ " empty=" ++ empty ++ " conflict=" ++ conflict ++ " " ++ description.first_line() ++ "\n"'

jj diff -r @ --summary
jj diff -r REV --summary

jj log -r 'ancestors(@-) & mutable()' -n 8 --no-graph \
  -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'

jj op log -n 1 -T 'self.id().short() ++ "\n"' --no-graph
jj op show -p
```

Reuse an already-good `@` description as the `jj commit -m` text (no editor, no rewrite):

```bash
jj commit -m "$(jj log -r @ --no-graph -T 'description')"
```

## Absorb leftovers

`jj absorb` moves each hunk to the closest mutable ancestor that last touched those lines. If the destination is ambiguous, the hunk stays in the source (`@` by default).

```bash
jj absorb path/a path/b
jj diff -r @ --summary          # what did not land
jj op show -p                   # where hunks went
```

Still-in-`@` hunks: leave them if they belong to the open concern; or `jj squash --from @ --into REV --use-destination-message path` when you know the rev; or keep editing `@`.

Restrict destinations (still only ancestors of source):

```bash
jj absorb -f @ -t 'mutable() & description(regex:"feat\\(api\\)")'
```

Do not pass `-i` / `--tool` unless filesets cannot name the hunks.

## Squash extras

```bash
# keep emptied source (rare; default abandons an emptied @ and opens a new empty WC)
jj squash --from @ --into REV --use-destination-message --keep-emptied

jj undo                         # last operation only
# jj op restore OP              # last resort; report OP first; user must ask
```

Prefer `--use-destination-message` for follow-ups. `-m` only when the ancestor’s why actually changed.

## Split then describe both sides

Default: selected paths stay in the original rev (`-m` names that side). Remaining paths become a **child** and keep the old description.

```bash
jj split path/a path/b -m "$(cat <<'EOF'
feat(scope): selected slice why

EOF
)"

jj log -n 5 --no-graph \
  -T 'change_id.short() ++ " empty=" ++ empty ++ " " ++ description.first_line() ++ "\n"'

# remaining side (usually the new child / @) if the old message is now a lie:
jj describe -m "$(cat <<'EOF'
feat(other): remaining slice why

EOF
)"
```

`--parallel` makes siblings instead of parent/child — only if the user asked for that shape. `-o`/`-A`/`-B` extract selected elsewhere; that is not the day-to-day mixed-WC split.

Path-args `jj commit FILESETS` also keeps selected in `@` and moves the rest to a new WC. Do not use it as the unrelated-prompt commit; `jj split` is the named split.

## Empty wip

```bash
jj abandon @     # only when @ is accidental empty/untitled and you mean to drop it
```

Abandoning `@` gives you a new empty WC. Do not abandon a described concern you still need.

## Bookmarks

`jj bookmark set NAME -r @` is optional and local. This skill does not create, duplicate, or delete `backup/*` bookmarks.
