directory="$(jq -r '.cwd // empty')"
if [ -z "$directory" ] || [ ! -d "$directory" ]; then
  exit 0
fi

directory="$(realpath "$directory")"
while :; do
  skills_directory="$directory/.agents/skills"
  # Personal skills are already exposed through Claude's native skill directory.
  if [ "$directory" != "$HOME" ] && [ -d "$skills_directory" ]; then
    while IFS= read -r -d '' skill; do
      printf '\nProject skill: %s\n' "$skill"
      sed -n '1{/^---$/!q;}; 2,/^---$/p' "$skill"
      printf 'Read this SKILL.md and its referenced resources when relevant.\n'
    done < <(find -L "$skills_directory" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0 | sort -z)
  fi
  if [ "$directory" = / ]; then
    break
  fi
  directory="$(dirname "$directory")"
done
