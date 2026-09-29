set -euo pipefail

bw_secret_config_path="${BW_SECRET_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/bw-secret/secrets.json}"
bw_secret_temp_file=""
bw_secret_session=""
bw_secret_value=""
bw_secret_lock_on_exit=false

bw_secret_cleanup() {
  if [ -n "$bw_secret_temp_file" ]; then
    rm -f "$bw_secret_temp_file"
  fi
  if [ "$bw_secret_lock_on_exit" = true ] && [ -n "$bw_secret_session" ]; then
    BW_SESSION="$bw_secret_session" bw --nointeraction lock --quiet || true
  fi
  unset BW_SESSION bw_secret_session bw_secret_value
}

trap bw_secret_cleanup EXIT

bw_secret_require_config() {
  if [ ! -r "$bw_secret_config_path" ]; then
    printf 'Bitwarden secret manifest is missing or unreadable: %s\n' "$bw_secret_config_path" >&2
    return 1
  fi
  if ! jq -e '
    .schemaVersion == 1
    and (.stateDirectory | type == "string" and startswith("/") and length > 1)
    and (.secrets | type == "array")
    and (([.secrets[].item] | length) == ([.secrets[].item] | unique | length))
    and (([.secrets[] | .destinations.environment.name? // empty] | length)
      == ([.secrets[] | .destinations.environment.name? // empty] | unique | length))
    and all(.secrets[]; (.item | type == "string" and test("^secret--[a-z0-9]+(-[a-z0-9]+)*--[a-z0-9]+(-[a-z0-9]+)*$"))
      and (.destinations | type == "object")
      and ((.destinations.environment // null) != null or (.destinations.file // null) != null)
      and ((.destinations.environment // null) == null
        or ((.destinations.environment | type == "object")
          and (.destinations.environment.name | type == "string" and test("^[A-Za-z_][A-Za-z0-9_]*$"))
          and (.destinations.environment.path | type == "string" and startswith("/") and length > 0)))
      and ((.destinations.file // null) == null
        or ((.destinations.file | type == "object")
          and (.destinations.file.path | type == "string" and startswith("/") and length > 0)
          and ((.destinations.file.argument // null) == null
            or (.destinations.file.argument | type == "string" and length > 0)))))
  ' "$bw_secret_config_path" >/dev/null; then
    printf 'Invalid Bitwarden secret manifest: %s\n' "$bw_secret_config_path" >&2
    return 1
  fi
}

bw_secret_find_entry() {
  jq -cer --arg item "$1" '.secrets[] | select(.item == $item)' "$bw_secret_config_path"
}

bw_secret_write_file() {
  local target_path="$1"
  local item="$2"
  local parent_directory

  case "$target_path" in
    /*) ;;
    *)
      printf 'Secret output path must be absolute for Bitwarden item %s: %s\n' "$item" "$target_path" >&2
      return 1
      ;;
  esac
  if [ -L "$target_path" ]; then
    printf 'Refusing to overwrite a symlink for Bitwarden item %s: %s\n' "$item" "$target_path" >&2
    return 1
  fi
  if [ -d "$target_path" ]; then
    printf 'Refusing to overwrite a directory for Bitwarden item %s: %s\n' "$item" "$target_path" >&2
    return 1
  fi

  parent_directory="$(dirname "$target_path")"
  mkdir -p "$parent_directory"
  bw_secret_temp_file="$(mktemp "${parent_directory%/}/.bw-secret.XXXXXXXXXX")"
  chmod 600 "$bw_secret_temp_file"
  printf '%s' "$bw_secret_value" > "$bw_secret_temp_file"
  chmod 400 "$bw_secret_temp_file"
  mv -f "$bw_secret_temp_file" "$target_path"
  bw_secret_temp_file=""
}

bw_lock() {
  local session=""
  local line=""
  case "$(uname -s)" in
    Linux)
      if command -v systemctl >/dev/null 2>&1; then
        while IFS= read -r line; do
          case "$line" in
            BW_SESSION=*) session="${line#BW_SESSION=}" ;;
          esac
        done < <(systemctl --user show-environment 2>/dev/null || true)
        systemctl --user unset-environment BW_SESSION >/dev/null 2>&1 || true
      fi
      ;;
    Darwin)
      session="$(/bin/launchctl getenv BW_SESSION 2>/dev/null || true)"
      /bin/launchctl unsetenv BW_SESSION >/dev/null 2>&1 || true
      ;;
    *)
      printf 'Unsupported operating system for clearing a legacy Bitwarden session.\n' >&2
      return 1
      ;;
  esac

  if [ -n "$session" ]; then
    BW_SESSION="$session" bw --nointeraction lock --quiet || true
  fi
  unset session
  printf 'Cleared any legacy Bitwarden session from the user service manager.\n'
}

bw_sync() {
  bw_secret_require_config

  local bw_status
  if ! bw_status="$(bw --nointeraction status 2>/dev/null)"; then
    printf 'Bitwarden CLI is not signed in. Run bw login once on this machine.\n' >&2
    return 1
  fi
  if [ "$(printf '%s' "$bw_status" | jq -r '.status // empty')" = "unauthenticated" ]; then
    printf 'Bitwarden CLI is not signed in. Run bw login once on this machine.\n' >&2
    return 1
  fi

  if [ -n "${BW_SESSION:-}" ]; then
    bw_secret_session="$BW_SESSION"
  elif ! bw_secret_session="$(bw unlock --raw)"; then
    printf 'Bitwarden unlock failed; no local secrets were refreshed.\n' >&2
    return 1
  else
    bw_secret_lock_on_exit=true
  fi
  if [ -z "$bw_secret_session" ]; then
    printf 'Bitwarden CLI returned an empty session.\n' >&2
    return 1
  fi

  export BW_SESSION="$bw_secret_session"
  if ! bw --nointeraction sync >/dev/null; then
    printf 'Bitwarden vault sync failed; no local secrets were refreshed.\n' >&2
    return 1
  fi

  local state_directory
  state_directory="$(jq -r '.stateDirectory' "$bw_secret_config_path")"
  umask 077
  mkdir -p "$state_directory"
  chmod 700 "$state_directory"

  local entry item environment_name environment_path file_path target_path previous_path
  local -a output_paths=()
  local count=0
  while IFS= read -r entry; do
    item="$(printf '%s' "$entry" | jq -r '.item')"
    environment_name="$(printf '%s' "$entry" | jq -r '.destinations.environment.name // empty')"
    environment_path="$(printf '%s' "$entry" | jq -r '.destinations.environment.path // empty')"
    file_path="$(printf '%s' "$entry" | jq -r '.destinations.file.path // empty')"
    if [ -n "$environment_name" ]; then
      case "$environment_name" in
        ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*)
          printf 'Invalid environment variable for Bitwarden item %s: %s\n' "$item" "$environment_name" >&2
          return 1
          ;;
      esac
    fi

    if ! bw_secret_value="$(bw --nointeraction get password "$item")"; then
      printf 'Could not retrieve the Password field for Bitwarden item: %s\n' "$item" >&2
      return 1
    fi
    if [ -z "$bw_secret_value" ]; then
      printf 'Bitwarden Password field is empty for item: %s\n' "$item" >&2
      return 1
    fi

    output_paths=( "$environment_path" "$file_path" )
    previous_path=""
    for target_path in "${output_paths[@]}"; do
      if [ -n "$target_path" ] && [ "$target_path" != "$previous_path" ]; then
        bw_secret_write_file "$target_path" "$item"
        previous_path="$target_path"
      fi
    done
    unset bw_secret_value
    count=$((count + 1))
  done < <(jq -c '.secrets[]' "$bw_secret_config_path")

  printf 'Refreshed %s Bitwarden secret(s) into local files.\n' "$count"
}

bw_exec() {
  local item=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --item)
        if [ "$#" -lt 2 ]; then
          printf 'Missing value for --item.\n' >&2
          return 2
        fi
        item="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        printf 'Usage: bw-secret exec --item ITEM -- COMMAND [ARGS...]\n' >&2
        return 2
        ;;
    esac
  done

  if [ -z "$item" ] || [ "$#" -eq 0 ]; then
    printf 'Usage: bw-secret exec --item ITEM -- COMMAND [ARGS...]\n' >&2
    return 2
  fi
  bw_secret_require_config

  local entry environment_name environment_path file_path file_argument
  if ! entry="$(bw_secret_find_entry "$item")"; then
    printf 'Bitwarden item is not declared in %s: %s\n' "$bw_secret_config_path" "$item" >&2
    return 1
  fi
  environment_name="$(printf '%s' "$entry" | jq -r '.destinations.environment.name // empty')"
  environment_path="$(printf '%s' "$entry" | jq -r '.destinations.environment.path // empty')"
  file_path="$(printf '%s' "$entry" | jq -r '.destinations.file.path // empty')"
  file_argument="$(printf '%s' "$entry" | jq -r '.destinations.file.argument // empty')"

  if [ -n "$environment_name" ]; then
    case "$environment_name" in
      ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*)
        printf 'Invalid environment variable in the Bitwarden manifest for item: %s\n' "$item" >&2
        return 1
        ;;
    esac
    if [ -L "$environment_path" ] || [ ! -f "$environment_path" ] || [ ! -r "$environment_path" ]; then
      printf 'Local secret cache is missing or unsafe for %s. Run bw-secret sync.\n' "$item" >&2
      return 1
    fi
    bw_secret_value="$(cat "$environment_path")"
    if [ -z "$bw_secret_value" ]; then
      printf 'Local secret cache is empty for %s. Run bw-secret sync.\n' "$item" >&2
      return 1
    fi
    export "$environment_name=$bw_secret_value"
    unset bw_secret_value
  fi

  if [ -n "$file_path" ] && { [ -L "$file_path" ] || [ ! -f "$file_path" ] || [ ! -r "$file_path" ]; }; then
    printf 'Local secret file is missing or unsafe for %s. Run bw-secret sync.\n' "$item" >&2
    return 1
  fi

  if [ -n "$file_argument" ]; then
    if [ -z "$file_path" ]; then
      printf 'A file argument is configured without a file destination for %s.\n' "$item" >&2
      return 1
    fi
    local -a wrapped_command=( "$@" )
    wrapped_command=( "${wrapped_command[0]}" "$file_argument" "$file_path" "${wrapped_command[@]:1}" )
    unset BW_SESSION
    exec "${wrapped_command[@]}"
  fi
  unset BW_SESSION
  exec "$@"
}

command="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi
case "$command" in
  lock)
    if [ "$#" -gt 0 ]; then
      printf 'Usage: bw-secret lock\n' >&2
      exit 2
    fi
    bw_lock
    ;;
  sync)
    if [ "$#" -gt 0 ]; then
      printf 'Usage: bw-secret sync\n' >&2
      exit 2
    fi
    bw_sync
    ;;
  exec)
    bw_exec "$@"
    ;;
  *)
    printf 'Usage: bw-secret {lock|sync|exec --item ITEM -- COMMAND [ARGS...]}\n' >&2
    exit 2
    ;;
esac
