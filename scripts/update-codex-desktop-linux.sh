#!/usr/bin/env bash
set -euo pipefail

input_name="codex-desktop-linux"
upstream_url="https://github.com/ilysenko/codex-desktop-linux"
flake_url_prefix="github:ilysenko/codex-desktop-linux"

usage() {
  cat <<'EOF'
Usage: update-codex-desktop-linux.sh [--check] [--dry-run]

Updates the commit-pinned codex-desktop-linux flake input to upstream HEAD.

Options:
  --check    Compare the current pin with upstream HEAD without changing files.
  --dry-run  Print the update that would be applied without changing files.
  -h, --help Show this help.

Environment:
  GIT_BIN    Path to git. Defaults to "git".
  NIX_BIN    Path to nix. Defaults to "nix".
  SED_BIN    Path to sed. Defaults to "sed".
  REPO_ROOT  Repository root. Defaults to the parent of this script directory.
EOF
}

mode="update"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      mode="check"
      ;;
    --dry-run)
      mode="dry-run"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

git_bin="${GIT_BIN:-git}"
nix_bin="${NIX_BIN:-nix}"
sed_bin="${SED_BIN:-sed}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${REPO_ROOT:-$(cd -- "$script_dir/.." && pwd)}"
flake_file="$repo_root/flake.nix"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

is_rev() {
  local value="$1"

  [[ "$value" =~ ^[0-9a-f]{40}$ ]]
}

require_command "$git_bin"
require_command "$sed_bin"

if [ "$mode" = "update" ]; then
  require_command "$nix_bin"
fi

if [ ! -f "$flake_file" ]; then
  echo "Could not find flake.nix at $flake_file" >&2
  exit 1
fi

current_rev="$("$sed_bin" -nE "s|^[[:space:]]*url = \"${flake_url_prefix}/([0-9a-f]{40})\";[[:space:]]*$|\\1|p" "$flake_file")"

if [ -z "$current_rev" ]; then
  echo "Could not find ${input_name}.url with a commit pin in $flake_file" >&2
  exit 1
fi

if [[ "$current_rev" == *$'\n'* ]]; then
  echo "Found more than one ${input_name}.url commit pin in $flake_file" >&2
  exit 1
fi

if ! is_rev "$current_rev"; then
  echo "Current pin is not a 40-character lowercase git revision: $current_rev" >&2
  exit 1
fi

upstream_rev=""
read -r upstream_rev _ < <("$git_bin" ls-remote "$upstream_url" HEAD)

if ! is_rev "$upstream_rev"; then
  echo "Could not resolve upstream HEAD for $upstream_url" >&2
  exit 1
fi

echo "Current ${input_name}:  $current_rev"
echo "Upstream HEAD:          $upstream_rev"

if [ "$current_rev" = "$upstream_rev" ]; then
  echo "${input_name} is already pinned to upstream HEAD."
  exit 0
fi

if [ "$mode" = "check" ]; then
  echo "${input_name} is behind upstream HEAD."
  exit 1
fi

if [ "$mode" = "dry-run" ]; then
  echo "Would update ${input_name} to $upstream_rev and refresh flake.lock."
  exit 0
fi

tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

"$sed_bin" -E "s|(url = \"${flake_url_prefix}/)[0-9a-f]{40}(\";)|\\1${upstream_rev}\\2|" "$flake_file" > "$tmp_file"
mv "$tmp_file" "$flake_file"
trap - EXIT

"$nix_bin" flake update "$input_name" --flake "$repo_root"

echo "Updated ${input_name} to $upstream_rev."
