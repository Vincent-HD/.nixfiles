#!/usr/bin/env bash
# Inventory conflicted jj commits for jj-solve-conflict.
# Usage: inventory.sh [revset]
# Default revset: conflicts()
set -euo pipefail

# Agent shells are PTYs. Bare jj opens `less` and hangs forever (often with
# empty captured output). timeout(1) does not save you — less ignores SIGTERM.
export PAGER=cat
export GIT_PAGER=cat
jj() {
	command jj --config=ui.paginate=never "$@"
}

SCOPE="${1:-conflicts()}"

if ! jj root >/dev/null 2>&1; then
	echo "error: not a jj repo" >&2
	exit 1
fi

echo "op $(jj op log -n 1 -T 'self.id().short()' --no-graph)"
echo "wc $(jj log -r @ -T 'change_id.short() ++ " " ++ if(empty, "(empty) ", "") ++ description.first_line()' --no-graph)"
echo "scope ${SCOPE}"
echo

echo "== roots =="
jj log -r "roots(${SCOPE})" --no-graph \
	-T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ " parents=" ++ parents.map(|c| c.change_id().short() ++ " " ++ c.description().first_line()).join(" | ") ++ "\n"'
echo

echo "== oldest first =="
count=0
while IFS= read -r line; do
	count=$((count + 1))
	echo "$count	$line"
done < <(
	jj log -r "${SCOPE}" --reversed --no-graph \
		-T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ " files=" ++ conflicted_files.map(|e| e.path().display()).join(",") ++ "\n"'
)
echo
echo "count ${count}"
