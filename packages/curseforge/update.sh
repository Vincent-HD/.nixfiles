#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl git gnused nix

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update.sh [--check] [--dry-run]

Updates packages/curseforge/default.nix from CurseForge's Linux update metadata.

Options:
  --check    Print the current and latest versions without prefetching or editing.
  --dry-run  Prefetch and print the change without editing default.nix.
EOF
}

check_only=0
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      check_only=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

repo_root="${CURSEFORGE_REPO_ROOT:-}"
if [ -z "$repo_root" ]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

package_file="$repo_root/packages/curseforge/default.nix"
if [ ! -f "$package_file" ]; then
  echo "Could not find $package_file" >&2
  exit 1
fi

metadata_url="https://curseforge.overwolf.com/electron/linux/latest-linux.yml"
metadata="$(curl -fsSL "$metadata_url")"
latest_full_version="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+)$/\1/p' <<< "$metadata" | head -n 1)"
latest_path="$(sed -nE 's/^[[:space:]]*path:[[:space:]]*([^[:space:]]+)$/\1/p' <<< "$metadata" | head -n 1)"

if [ -z "$latest_full_version" ] || [ -z "$latest_path" ]; then
  echo "Could not read latest CurseForge version/path from $metadata_url" >&2
  exit 1
fi

latest_version="${latest_full_version%-*}"
latest_build="${latest_full_version##*-}"

if [ "$latest_version" = "$latest_full_version" ] || [ -z "$latest_build" ]; then
  echo "Could not split CurseForge version/build from $latest_full_version" >&2
  exit 1
fi

current_version="$(sed -nE 's/^    version = "([^"]+)";$/\1/p' "$package_file")"
current_build="$(sed -nE 's/^    build = "([^"]+)";$/\1/p' "$package_file")"

if [ -z "$current_version" ] || [ -z "$current_build" ]; then
  echo "Could not read current CurseForge version/build from $package_file" >&2
  exit 1
fi

echo "curseforge current: $current_version-$current_build"
echo "curseforge latest:  $latest_version-$latest_build"

if [ "$current_version-$current_build" = "$latest_version-$latest_build" ]; then
  echo "curseforge is already up to date."
  exit 0
fi

if [ "$check_only" -eq 1 ]; then
  exit 0
fi

prefetch_url="https://curseforge.overwolf.com/electron/linux/$latest_path"
prefetch_output="$(nix store prefetch-file --json "$prefetch_url")"
latest_hash="$(sed -nE 's/.*"hash":"([^"]+)".*/\1/p' <<< "$prefetch_output")"

if [ -z "$latest_hash" ]; then
  echo "Could not determine hash for $prefetch_url" >&2
  echo "$prefetch_output" >&2
  exit 1
fi

echo "curseforge hash:    $latest_hash"

if [ "$dry_run" -eq 1 ]; then
  echo "Dry run: would update $package_file"
  exit 0
fi

sed -i -E \
  's#^(    version = ")[^"]+(";)$#\1'"$latest_version"'\2#' \
  "$package_file"
sed -i -E \
  's#^(    build = ")[^"]+(";)$#\1'"$latest_build"'\2#' \
  "$package_file"
sed -i -E \
  's#^(      hash = ")[^"]+(";)$#\1'"$latest_hash"'\2#' \
  "$package_file"

echo "Updated $package_file"
