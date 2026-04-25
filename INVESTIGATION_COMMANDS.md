# Investigation Command Reference

This file captures the shell command patterns used during this session, normalized into reusable forms for future NixOS / Home Manager / Niri / Noctalia investigations.

Near-duplicates are grouped together. Very specific or low-reuse commands are kept in a separate section at the end.

## Conventions

Use these placeholders when adapting commands:

```bash
REPO=/home/vincent/.nixfiles
HOST=pc-fixe
USER=vincent
NIX_EVAL_FEATURES='extra-experimental-features = nix-command flakes dynamic-derivations'
```

## Core Flake / Input Discovery

### Get an input source path from the current flake

```bash
nix eval --impure --expr '(builtins.getFlake "git+file:///home/vincent/.nixfiles").inputs.niri.outPath' --raw
```

Purpose: resolve the exact checked-out source path for a flake input such as `niri`, `nixpkgs`, or `home-manager`.

Use when:
- you want to inspect upstream module sources from the currently locked flake
- you need a stable path into `/nix/store` for grep / read / compare work

Variants:

```bash
nix eval --impure --expr '(builtins.getFlake "git+file:///home/vincent/.nixfiles").inputs.nixpkgs.outPath' --raw
nix eval --impure --expr '(builtins.getFlake "git+file:///home/vincent/.nixfiles").inputs.home-manager.outPath' --raw
```

### Check which package from an overlay is actually selected

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.niri.package.name'
```

Purpose: confirm whether you are using `niri-stable`, `niri-unstable`, or another overridden package.

## Niri Action / Capability Discovery

### List Niri actions and filter by keyword

```bash
niri msg action 2>&1 | grep -iE 'workspace|monitor|consume|expel|overview'
```

Purpose: discover which compositor actions exist before binding them.

Good follow-up patterns:

```bash
niri msg action 2>&1 | sed -n '/set-column-width/,+20p'
niri msg action 2>&1 | sed -n '/move-window-to-workspace/,+20p'
niri msg action 2>&1 | grep -iE 'move-window-to-monitor|move-column-to-monitor'
niri msg action 2>&1 | grep -iE 'consume|expel'
```

Purpose: inspect a smaller section around actions you plan to bind.

### Smoke-test a Niri action in the running session

```bash
niri msg action open-overview
```

Purpose: quickly verify that an action exists and works in the current session.

Use only when it is safe for the action to have an immediate visible effect.

## Noctalia IPC Discovery

### Show Noctalia IPC help

```bash
noctalia-shell ipc --help
```

Purpose: understand CLI shape and supported IPC subcommands.

### List all Noctalia IPC targets

```bash
noctalia-shell ipc show
```

Purpose: discover callable IPC targets and functions such as `launcher`, `settings`, `bar`, or plugin handlers.

### Filter Noctalia IPC targets for a feature

```bash
noctalia-shell ipc show 2>&1 | grep -iE 'hot|corner|workspace|overview|window'
```

Purpose: quickly check whether Noctalia already exposes a target for the behavior you want.

### Probe a specific Noctalia target

```bash
noctalia-shell ipc call cb --help
```

Purpose: inspect argument shape for a specific handler before trying to call it.

## Home Manager / Config Evaluation

### Evaluate the generated Niri config

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.niri.finalConfig' --raw
```

Purpose: see the exact final `config.kdl` that Home Manager would generate.

Use when:
- debugging why a bind does not appear
- checking whether a setting rendered as expected
- comparing generated config before and after a change

### Evaluate a specific Home Manager-managed file

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/config.kdl".text' --raw
```

Purpose: inspect the final text for a specific XDG-managed file when you override or replace upstream file ownership.

Related useful checks:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile.niri-config.enable'

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.boot.loader.systemd-boot.configurationLimit'
```

Purpose:
- confirm that an upstream managed file entry is disabled
- confirm a NixOS option evaluates to the intended value

## NixOS Host Evaluation

### Evaluate the host toplevel derivation

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel.drvPath' --raw
```

Purpose: confirm the full NixOS host still evaluates end-to-end after a module or input change.

## Niri Config Validation

### Validate generated config piped from eval

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.niri.finalConfig' --raw 2>/dev/null \
| niri validate -c /dev/stdin
```

Purpose: catch syntax or semantic errors in generated Niri config before rebuilding.

Use when the config has no external includes.

### Validate a generated config that uses `include`

```bash
tmpdir=$(mktemp -d)
cd "$REPO" && \
NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/config.kdl".text' --raw 2>/dev/null > "$tmpdir/config.kdl" && \
NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/recent-windows.kdl".text' --raw 2>/dev/null > "$tmpdir/recent-windows.kdl" && \
niri validate -c "$tmpdir/config.kdl"
```

Purpose: validate the real final config layout when the main file references sibling files via `include`.

## Generated Config Inspection

### Inspect one section of generated config

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/config.kdl".text' --raw 2>/dev/null \
| sed -n '/binds {/,/spawn-at-startup/p'
```

Purpose: inspect rendered bind definitions without printing the whole config.

Useful section patterns:

```bash
... | sed -n '/input {/,/layout {/p'
... | sed -n '/gestures {/,/xwayland-satellite/p'
... | sed -n '/binds {/,/spawn-at-startup/p'
```

### Confirm that specific rendered lines exist

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/config.kdl".text' --raw 2>/dev/null \
| grep -E 'Mod\+Alt\+Up|Mod\+Alt\+Down|ampersand|eacute'
```

Purpose: verify that important binds or AZERTY aliases made it into the generated config.

## Formatting / Static Checks

### Format a Nix file with nixfmt

```bash
cd "$REPO" && nix shell nixpkgs#nixfmt -c nixfmt modules/niri.nix
```

Purpose: format changed Nix files even when the repo has no `package.json` / `pnpm fmt`.

General form:

```bash
cd "$REPO" && nix shell nixpkgs#nixfmt -c nixfmt path/to/file.nix
```

### Check for available formatters

```bash
command -v nixfmt-rfc-style nixfmt alejandra 2>/dev/null
```

Purpose: quickly see which formatter binaries are already on the machine.

## Git State Inspection

### Separate staged and unstaged changes for specific paths

```bash
git status --short
git diff --cached -- path/to/file.nix
git diff -- path/to/file.nix
```

Purpose: inspect a dirty worktree without losing track of what is already staged versus what is still only in the working tree.

Use when:
- the repo already contains unrelated changes
- you need to avoid staging someone else’s work
- a new tracked file must be added for import-tree to discover it

## Runtime / Environment Checks

### Check NVIDIA video engine usage

```bash
nvidia-smi pmon -c 1
nvidia-smi dmon -s u -c 1
```

Purpose: see which processes are using the GPU and whether encoder / decoder engines are active.

### Inspect the currently deployed Niri config

```bash
grep -n 'recent\|WheelScroll\|focus-follows' ~/.config/niri/config.kdl
```

Purpose: compare the live config on disk with the generated config from `nix eval`.

### Inspect a portion of the live Niri config

```bash
sed -n '1,80p' ~/.config/niri/config.kdl
```

Purpose: check what is actually deployed after a switch or failed activation.

### Check whether a binary exists in the session

```bash
which noctalia-shell
```

Purpose: confirm that a runtime dependency is actually available in the current user environment.

## Session-Specific / Less Reusable Commands

These were useful in this session, but are more situational.

### Inspect overlay-provided package names

```bash
nix eval --impure --expr '
let
  f = builtins.getFlake "git+file:///home/vincent/.nixfiles";
  pkgs = import f.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ f.inputs.niri.overlays.niri ];
  };
in
  builtins.attrNames (pkgs.lib.intersectAttrs
    (builtins.listToAttrs (map (n: { name = n; value = null; }) [ "niri" "niri-stable" "niri-unstable" ]))
    pkgs)
'
```

Purpose: confirm which Niri package attributes an overlay exports.

### Probe a specific generated bind block

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/config.kdl".text' --raw 2>/dev/null \
| sed -n '/binds {/,/spawn-at-startup/p' \
| grep -E 'Mod\+Alt\+Left|Mod\+Alt\+Right|Mod\+Shift\+Left|Mod\+Shift\+Right'
```

Purpose: targeted inspection while iterating quickly on one binding family.

### Query a specific file-backed Home Manager option

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."niri/recent-windows.kdl".text' --raw
```

Purpose: useful when a config is split across includes and you need to validate them together.

### Session-specific smoke tests with visible effects

```bash
niri msg action open-overview
niri msg action focus-window-up
noctalia-shell ipc call cb up
```

Purpose: manual experiments while discovering behavior. These are best used sparingly because they can visibly affect the running session or depend on context.

## Notes

- Many `nix eval` commands in this repo need:

  ```bash
  NIX_CONFIG='extra-experimental-features = nix-command flakes dynamic-derivations'
  ```

  because evaluation of generated Home Manager text can otherwise fail in this environment.

- Prefer validating before rebuilding whenever you touch `programs.niri.settings`, `xdg.configFile."niri/*"`, or Home Manager-managed Niri files.

- When a command touches live compositor state (`niri msg action ...`, `noctalia-shell ipc call ...`), assume it has immediate visible side effects.
