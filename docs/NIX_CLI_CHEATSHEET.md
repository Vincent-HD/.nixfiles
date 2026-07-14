# Nix CLI Cheat Sheet for AI Agents

Use this as a quick command map for this flake. It is biased toward safe
inspection, validation, and package-maintenance workflows before any command that
mutates the system, store roots, lock file, or source tree.

## Repo Defaults

Run repo-sensitive commands from the flake root:

```bash
REPO=/home/vincent/.nixfiles
HOST=pc-fixe
DARWIN_HOST=macbook-pro
USER=vincent
NIX_EVAL_FEATURES='extra-experimental-features = nix-command flakes dynamic-derivations'
```

Current config already provides `nil`, `nixfmt`, `jujutsu`/`jj`, `comma`,
`direnv` + `nix-direnv`, `mcp-nixos` on Linux, `nixswitch`, and general CLI
helpers such as `rg`, `fd`, `bat`, `jaq`, `yq`, `delta`, and `lazygit`.

The shared command-line module also installs Nix-oriented tools: `nh`, `nvd`,
`nix-output-monitor` (`nom` command), `deadnix`, `statix`, and `nurl`.
`nix-init` and `nix-update` are not installed globally here; use them via
one-off `nix shell`/`nix run` commands when packaging or update work calls for
them.

## Safety Rules

- Start with `git status --short`; assume unrelated changes belong to someone
  else and leave them alone.
- Prefer read-only commands first: `nix eval`, `nix flake show`, `nix build
  --dry-run`, `deadnix --fail`, and repo-configured `statix check`.
- Prefer one-off tools with `nix shell nixpkgs#<pkg> -c <cmd>` until the user
  asks to install them permanently.
- Avoid `switch`, `nixswitch`, `nh clean`, `nix flake update`, `nix flake lock
  --update-input`, `nix-update`, `statix fix`, `deadnix --edit`, and `direnv
  allow` unless the task explicitly calls for that mutation.
- Use `--no-link` for validation builds so no `result` symlink is created.
- Do not use `nixpkgs#nom` for build output monitoring; that package is an RSS
  reader. Use `nixpkgs#nix-output-monitor`, which provides the `nom` command.

## Safe Validation Ladder

```bash
cd "$REPO" && git status --short
```

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel.drvPath' --raw
```

For shared Linux/macOS changes, validate both host graphs:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel.drvPath' --raw

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#darwinConfigurations.'"$DARWIN_HOST"'.system' --raw
```

Build without linking:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel'
```

Dry-run when you only need evaluation plus the build plan:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel' --dry-run
```

Run a full check only when the change is broad enough to justify it:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" nix flake check
```

## Core Nix Commands

| Command | What it does | Agent-safe pattern |
| --- | --- | --- |
| `nix eval` | Reads evaluated options, package attrs, paths, and generated config. | Use `--json` for attrsets and booleans; `--raw` for strings and store paths. |
| `nix build` | Realizes derivations. | Use `--dry-run` first, then `--no-link --print-out-paths`. |
| `nix shell` | Runs temporary tools without editing config. | `nix shell nixpkgs#deadnix -c deadnix --fail .` |
| `nix run` | Runs an app output directly. | Good for known app flakes; prefer `nix shell -c` when command name matters. |
| `nix develop` | Enters a dev shell. | Use to reproduce project-local toolchains; it can build dependencies. |
| `nix log` | Reads build logs for a failed derivation. | `nix log /nix/store/<failed>.drv` |
| `nix why-depends` | Explains closure edges. | Compare the host toplevel against a suspicious package. |
| `nix store prefetch-file` | Fetches a file and prints an SRI hash. | Safe for fixed-output package updates. |
| `nix hash convert` | Converts between hash encodings. | Useful when an existing derivation expects nix32. |

Common inspection snippets:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.<option.path>' --json

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.<hm.option.path>' --json
```

## Apply Commands

These mutate the running system or activation state. Use them only when the user
asked for an apply/test, not as routine validation.

```bash
cd "$REPO" && sudo nixos-rebuild test --flake ".#$HOST"
cd "$REPO" && sudo nixos-rebuild switch --flake ".#$HOST"
cd "$REPO" && sudo darwin-rebuild switch --flake ".#$DARWIN_HOST"
nixswitch
```

`nixswitch` is this repo's wrapper: Linux switches `pc-fixe`; macOS switches
`macbook-pro`.

## Requested Tool Cheats

### `nh`

`nh` is an ergonomic frontend for NixOS, Home Manager, and nix-darwin commands.
It can add nicer build output, diffs, confirmations, search, and generation
management.

```bash
nix shell nixpkgs#nh -c nh search packages nil
nix shell nixpkgs#nh -c nh search options --scope all services.pipewire
```

Use the earlier `nix build --no-link` or `nom build --no-link` patterns as the
default safe validation path. Use `nh build` when you specifically want its
review UI:

```bash
nix shell nixpkgs#nh -c nh os build "$REPO#$HOST"
nix shell nixpkgs#nh -c nh darwin build "$REPO#$DARWIN_HOST"
```

Use `nh os test "$REPO#$HOST"` or `nh os switch "$REPO#$HOST"` only
when activation is requested. Treat `nh clean` like garbage collection: it can
remove gcroots, including result and direnv roots.

### `nix-output-monitor` / `nom`

`nix-output-monitor` provides `nom`, a readable wrapper around Nix build output.

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix shell nixpkgs#nix-output-monitor -c nom build --no-link --print-out-paths \
  '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel'
```

Use it when normal Nix output is too noisy or when a long build needs a tree view.

### `nvd`

`nvd` compares two system closures and highlights package version changes.

```bash
cd "$REPO" && new_system="$(NIX_CONFIG="$NIX_EVAL_FEATURES" \
  nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel')" \
&& nix shell nixpkgs#nvd -c nvd diff /run/current-system "$new_system"
```

Use before switching to summarize what a rebuild would change.

### `deadnix`

`deadnix` finds unused bindings and arguments in Nix files.

```bash
cd "$REPO" && nix shell nixpkgs#deadnix -c deadnix --fail .
```

Only use edit mode on explicitly scoped paths after reviewing the findings:

```bash
nix shell nixpkgs#deadnix -c deadnix --edit modules/example.nix
```

### `statix`

`statix` lints Nix code for suspicious patterns and style issues.

```bash
cd "$REPO" && nix shell nixpkgs#statix -c statix check --config checks/statix.toml .
```

`statix fix` edits files. Scope it tightly and use it only when the requested
change includes cleanup:

```bash
nix shell nixpkgs#statix -c statix fix --config checks/statix.toml modules/example.nix
```

### `nurl`

`nurl` generates Nix fetcher calls from source URLs.

```bash
nix shell nixpkgs#nurl -c nurl https://github.com/owner/project
nix shell nixpkgs#nurl -c nurl https://github.com/owner/project/tree/v1.2.3
```

Use it before hand-writing `fetchFromGitHub` or similar source fetchers.

### `nix-init`

`nix-init` scaffolds a Nix package expression from a URL.

```bash
mkdir -p /tmp/nix-init-scratch && cd /tmp/nix-init-scratch
nix shell nixpkgs#nix-init -c nix-init -u https://github.com/owner/project
```

Run it in a scratch directory or the intended package directory because it writes
files.

### `nix-update`

`nix-update` updates package versions and fixed-output hashes. This repo keeps
known compatible commands in `scripts/update-pins.json` and
`docs/UPDATE_COMMANDS.md`.

```bash
nix run .#update-pins -- --dry-run
nix run .#update-pins -- --only codex,curseforge
nix run .#update-pins -- --validate fast
```

Use it for update tasks only. It mutates package files and may update hashes.
Custom flake inputs are updated with `nix flake update <name>`, not with
`nix-update`.

## Formatter and LSP Context

Current repo state uses `pkgs.nil` and `pkgs.nixfmt`.

- `nil`: current configured Nix language server.
- `nixd`: previous Nix language server; avoid adding it back unless intentionally testing.
- `nixfmt`: current official formatter package/command in nixpkgs unstable.
- `nixfmt-rfc-style`: older name seen in older docs or machines; prefer
  `nixfmt` here unless a specific environment still provides only the old binary.

Format changed Nix files:

```bash
cd "$REPO" && nix shell nixpkgs#nixfmt -c nixfmt path/to/file.nix
```

Check what is available in the current session:

```bash
command -v nil nixfmt nixfmt-rfc-style 2>/dev/null
```

## `comma`

`comma` runs commands found through the nix-index database without permanently
installing them. In this repo it is enabled through Home Manager with the
prebuilt database.

```bash
, jq --version
, shellcheck --version
```

Use it for quick manual probing. For reproducible agent logs and docs, prefer the
explicit package form:

```bash
nix shell nixpkgs#shellcheck -c shellcheck --version
```

## `direnv` and `nix-direnv`

`direnv` loads project environments; `nix-direnv` makes `use flake` fast and
persistent. This repo enables Bash and Zsh integration and silences direnv's own
load chatter.

```bash
direnv status
direnv reload
```

Only run `direnv allow` after reading the `.envrc` and confirming the task wants
that trust change:

```bash
sed -n '1,160p' .envrc
direnv allow
```

## Jujutsu (`jj`)

This repo configures Jujutsu and JJ-aware prompt tooling. Use JJ commands when
the workspace is a JJ repo; keep `git status --short` as the baseline in normal
Git worktrees.

```bash
jj status
jj diff
jj log -n 20
```

Avoid history-changing or remote-changing commands such as `jj abandon`,
`jj squash`, `jj rebase`, `jj git push`, and `jj git fetch` unless the user asks.

## Supporting CLI Helpers

These are already configured and are useful during Nix work:

| Tool | Use |
| --- | --- |
| `rg` | Fast text search; prefer over `grep` for repo inspection. |
| `fd` | Fast file discovery; mirrors the shell alias replacing `find`. |
| `bat` | Read files with syntax highlighting; shell alias replaces `cat`. |
| `jaq` / `yq` | Query JSON/YAML from `nix eval --json` or generated config. |
| `delta` | Readable Git diffs and pager integration. |
| `lazygit` | Manual Git inspection UI; avoid automated mutation from it. |
| `hyperfine` | Benchmark commands when performance is the task. |

## Quick Agent Flow

1. Inspect: `git status --short`, `rg`, `fd`, targeted `sed -n`.
2. Edit only requested files.
3. Format scoped Nix files with `nixfmt`.
4. Run `deadnix --fail` or repo-configured `statix check` only when relevant to the change.
5. Validate with `nix eval`, then `nix build --dry-run` or `--no-link`.
6. Use `nvd`/`nom` for reviewability when the build output or closure delta
   matters.
7. Apply with `test`, `switch`, `nh os switch`, or `nixswitch` only on request.
