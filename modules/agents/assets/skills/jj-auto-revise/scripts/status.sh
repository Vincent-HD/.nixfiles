#!/usr/bin/env bash
# Snapshot @ for the jj-auto-revise progress block.
# Usage: status.sh
set -euo pipefail

if ! jj root >/dev/null 2>&1; then
	echo "error: not a jj repo" >&2
	exit 1
fi

echo "op $(jj op log -n 1 -T 'self.id().short()' --no-graph)"
echo "wc $(jj log -r @ --no-graph -T 'change_id.short() ++ " empty=" ++ empty ++ " conflict=" ++ conflict ++ " " ++ description.first_line()')"
echo
echo "== files @ =="
jj diff -r @ --summary
echo
echo "== mutable ancestors =="
jj log -r 'ancestors(@-) & mutable()' -n 8 --no-graph \
	-T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
