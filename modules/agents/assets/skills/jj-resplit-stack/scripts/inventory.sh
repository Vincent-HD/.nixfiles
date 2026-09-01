#!/usr/bin/env bash
# Inventory files in TO vs BASE for jj-resplit-stack (squash-blob leftovers).
# Usage: inventory.sh BASE [TO]
# Default TO=@
set -euo pipefail

# Agent shells are PTYs. Bare jj opens `less` and hangs forever (often with
# empty captured output). timeout(1) does not save you — less ignores SIGTERM.
export PAGER=cat
export GIT_PAGER=cat
jj() {
	command jj --config=ui.paginate=never "$@"
}

if [[ $# -lt 1 ]]; then
	echo "usage: inventory.sh BASE [TO]" >&2
	exit 2
fi

BASE="$1"
TO="${2:-@}"

if ! jj root >/dev/null 2>&1; then
	echo "error: not a jj repo" >&2
	exit 1
fi

echo "op $(jj op log -n 1 -T 'self.id().short()' --no-graph)"
echo -n "wc "
jj log -r @ --no-graph \
	-T 'change_id.short() ++ " " ++ if(empty, "(empty) ", "") ++ description.first_line() ++ "\n"'
echo -n "base "
jj log -r "${BASE}" --no-graph \
	-T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
echo -n "to "
jj log -r "${TO}" --no-graph \
	-T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ if(empty, "(empty) ", "") ++ description.first_line() ++ "\n"'
echo

echo "== leftover vs BASE =="
count=0
while IFS= read -r line; do
	[[ -z "$line" ]] && continue
	count=$((count + 1))
	echo "$count	$line"
done < <(jj diff --from "${BASE}" --to "${TO}" --summary)
echo
if [[ "$count" -eq 0 ]]; then
	echo "count 0"
	base_id=$(jj log -r "${BASE}" --no-graph -T 'commit_id')
	to_id=$(jj log -r "${TO}" --no-graph -T 'commit_id')
	if [[ "$base_id" == "$to_id" ]]; then
		echo "empty leftover: TO is BASE — do not abandon BASE"
	else
		echo "empty, abandon blob"
	fi
else
	echo "count ${count}"
fi
