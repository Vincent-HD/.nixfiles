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

When passing arguments to a flake app, separate them from Nix's own options:

```bash
nix run .#<app> -- <app-options>
```

## Generated Nix / Expression Checks

### Parse a generated Nix expression without evaluating it

```bash
nix-instantiate --parse --expr '<nix-expression>'
```

Purpose: smoke-test the syntax emitted by a generator while keeping evaluation
out of the check. Use this before nix eval when debugging an expression
printer or a generated .nix file.

### Evaluate JSON-compatible Nix data strictly with nix-instantiate

```bash
nix-instantiate --eval --json --strict --expr '<nix-data-expression>'
```

Purpose: inspect a fully evaluated attrset/list fixture emitted by a generator
when recursive strictness is required. The modern nix eval command in the local
Nix version has no --strict flag; use it without --strict for ordinary
JSON-compatible evaluation.

Use only for JSON-compatible data; functions, derivations, paths and string
contexts need a target-specific expression or a focused Nix inspection.

## Core Flake / Input Discovery

### Get an input source path from the current flake

```bash
nix eval --impure --expr '(builtins.getFlake "path:/home/vincent/.nixfiles").inputs.niri.outPath' --raw
```

Purpose: resolve the exact checked-out source path for a flake input such as `niri`, `nixpkgs`, or `home-manager`.

Use when:
- you want to inspect upstream module sources from the currently locked flake
- you need a stable path into `/nix/store` for grep / read / compare work

Variants:

```bash
nix eval --impure --expr '(builtins.getFlake "path:/home/vincent/.nixfiles").inputs.nixpkgs.outPath' --raw
nix eval --impure --expr '(builtins.getFlake "path:/home/vincent/.nixfiles").inputs.home-manager.outPath' --raw
```

### Validate shared modules across configured hosts

```bash
nix eval '.#nixosConfigurations.<linux-host>.config.system.build.toplevel.drvPath' --raw
nix eval '.#darwinConfigurations.<darwin-host>.system' --raw
```

Purpose: evaluate the system graph for each configured platform after changing a shared module or
Home Manager feature, without building or applying either host.

### Compare default and specialized NixOS kernel paths

```bash
nix eval --raw ".#nixosConfigurations.${HOST}.config.boot.kernelPackages.kernel.name"
nix eval --raw ".#nixosConfigurations.${HOST}.config.specialisation.<name>.configuration.boot.kernelPackages.kernel.name"
nix eval --json ".#nixosConfigurations.${HOST}.config.boot.extraModulePackages" \
  --apply 'builtins.map (package: package.name or "")'
nix eval --json ".#nixosConfigurations.${HOST}.config.specialisation.<name>.configuration.boot.extraModulePackages" \
  --apply 'builtins.map (package: package.name or "")'
```

Purpose: compare the default and alternate kernel paths and confirm that out-of-tree modules such as
NVIDIA or a custom kernel module are rebuilt against the selected kernel before switching or rebooting.

Use when:
- a host exposes an alternate kernel, scheduler, or hardware profile through `specialisation.*`
- a default kernel has recently changed and you need to verify the fallback specialization's module graph

## Package / Derivation Inspection

### Determine the executing Nix platform

```bash
nix eval --raw --impure --expr builtins.currentSystem
```

Purpose: identify the platform whose package source or release artifact an update command should refresh.

Use when updating a package with platform-selected source hashes. Run the update on the target platform; do not synchronize hashes for other systems.

### Prefetch a commit-pinned GitHub source with submodules

```bash
nix run nixpkgs#nix-prefetch-git -- --url <git-url> --rev <commit> --fetch-submodules --quiet
```

Purpose: obtain the fixed-output hash for a reproducible derivation whose upstream source is pinned to a commit and includes Git submodules. Review the commit and its build changes before updating the package.

### Check a package output on a target platform

```bash
SYSTEM=x86_64-linux
nix eval --raw ".#packages.${SYSTEM}.<pkg>.pname"
nix eval --raw ".#packages.${SYSTEM}.<pkg>.version"
```

Purpose: confirm that a flake package exists for the platform an updater is targeting before running `nix-update`. This is especially useful when the current host does not provide a Linux-only output.

### Build a package for the current platform

```bash
SYSTEM=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build ".#packages.${SYSTEM}.<pkg>" --no-link
```

Purpose: validate the platform-specific artifact and catch fixed-output hash mismatches before rebuilding the full host configuration.

### Inspect a fixed-output derivation after a hash mismatch

```bash
nix derivation show <derivation.drv> \
  | jq '.derivations[] | .env | {name, version, src, outputHash, nativeBuildInputs}'
```

Purpose: compare the declared fixed-output hash and the source/toolchain used by a failing derivation. This helps distinguish a stale source hash from a change in the fetcher or build toolchain.

### Syntax-check generated shell configuration

```bash
nix eval --raw ".#<host-config>.config.home-manager.users.<user>.programs.zsh.initContent" | zsh -n
nix eval --raw ".#<host-config>.config.home-manager.users.<user>.home.activation.<feature>.data" | zsh -n
```

Purpose: catch quoting and shell-syntax errors in generated Home Manager shell initialization and activation snippets without applying the configuration.

### Read a package version and source position from the evaluated package set

```bash
nix eval '.#nixosConfigurations.'"$HOST"'.pkgs.<pkg>.version' --raw
nix eval '.#nixosConfigurations.'"$HOST"'.pkgs.<pkg>.meta.position' --raw
```

Purpose: identify the exact nixpkgs package version and source file before overriding or pinning it.

### Verify a package variant's build features

```bash
nix eval --json nixpkgs#<pkg>.cmakeFlags
nix run nixpkgs#<pkg> -- --version
```

Purpose: inspect feature flags on a specialized package variant and confirm the compiled configuration reported by its executable before wiring it into a Home Manager module.

### Inspect the rendered Home Manager package list

```bash
nix eval --json '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.packages'
```

Purpose: confirm which packages are attached to the user profile and spot overrides by name.

### List names of rendered Home Manager packages

```bash
nix eval --json '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.packages' \
  --apply 'map (package: package.name or "")'
```

Purpose: locate a generated wrapper or helper package by name before building or inspecting its
store output, without printing the full package list.

### Find duplicate packages in a rendered Home Manager list

```bash
nix eval --json \
  '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.<hm.package-list-option>' \
  --apply '
    packages:
    let
      groups = builtins.groupBy (package: package.name or "") packages;
      counts = builtins.mapAttrs
        (name: values: { inherit name; count = builtins.length values; })
        groups;
    in
    builtins.filter (entry: entry.count > 1) (builtins.attrValues counts)'
```

Purpose: find packages contributed by multiple composed modules after option merging. Start with
`home.packages`; the same pattern also works for `environment.systemPackages`. Identical store paths
added internally by Home Manager can be harmless, so trace local declarations before removing one.

### Inspect a rendered Home Manager shell option

```bash
nix eval --raw '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.zsh.shellAliases.<alias>'
```

Purpose: verify the effective value of a shell alias or other specific Home Manager shell option after module merging.

### Inspect a rendered Home Manager config file

```bash
nix eval --raw '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."<path>".text'
```

Purpose: verify the exact text generated for a Home Manager-managed application configuration after module merging.

### Compare and persist a running DMS configuration

```bash
persist-dms --dry-run
persist-dms
persist-dms --watch
```

Purpose: read DMS's in-memory settings through IPC, compare them with the defaults from the
installed DMS package, and update the generated settings file. The normal command commits only
that generated file; `--watch` polls with a debounce and commits each stable change. Use
`nix run .#persist-dms -- --dry-run` before the helper is installed in the user profile.

For applications with a config validator, pipe the rendered file through a process substitution:

```bash
<app> +validate-config --config-file=<(nix eval --raw '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."<path>".text')
```

Purpose: validate generated application configuration without first activating the system.

### Inspect a specific Home Manager app package

```bash
nix eval --raw '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.nixcord.discord.package.pname'
```

Purpose: confirm the exact app package selected after any override or launcher patch.

### Build one package selected from the Home Manager list

```bash
nix build --impure --no-link --expr '
let
  flake = builtins.getFlake "path:/home/vincent/.nixfiles";
  pkg = builtins.head (
    builtins.filter (
      p:
      (p.pname or "") == "<pkg-name-or-wrapper-name>"
      || (p.name or "") == "<pkg-name-or-wrapper-name>"
    ) flake.nixosConfigurations.pc-fixe.config.home-manager.users.vincent.home.packages
  );
in pkg
'
```

Purpose: force a specific HM-managed package or wrapper package to build even when it has no dedicated flake output.

### Build a package with a compatible dependency override

```bash
nix build --impure --no-link --print-out-paths --expr '
let
  flake = builtins.getFlake "path:/home/vincent/.nixfiles";
  pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; };
in (pkgs.<package>.override { <dependency> = pkgs.<compatible-dependency>; })
'
```

Purpose: verify a package against an older or alternate dependency when the current nixpkgs dependency has an incompatible API. Use this to test a narrow compatibility override before wiring it into a module.

### Build an unfree flake package

```bash
cd "$REPO" && NIXPKGS_ALLOW_UNFREE=1 NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --impure --no-link --print-out-paths '.#<package>'
```

Purpose: realize a flake package whose metadata is marked unfree while preserving the repository's normal experimental-feature settings.

### Build the evaluated Home Manager package directly

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.nixcord.discord.package'
```

Purpose: build the exact HM-selected package when you already know the option path you want to verify.

### Build the Home Manager activation package

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.activationPackage'
```

Purpose: realize generated Home Manager wrappers, service units, and file sources after changing a
Home Manager module, catching shell-check or generated-file failures without switching the host.

### Inspect a rendered Home Manager activation script

```bash
GENERATION=$(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.activationPackage')
bash -n "$GENERATION/activate"
rg -n -C 6 '<activation-marker-or-command>' "$GENERATION/activate"
```

Purpose: verify the exact shell emitted for a Home Manager activation step after evaluation, including
the pinned store paths and quoting that are not visible in the Nix module source.

### Run colocated Bun tests for a Nix-managed TypeScript asset

```bash
nix run nixpkgs#bun -- test modules/<module>/assets/<asset>/
```

Purpose: run unit and integration tests placed beside a TypeScript asset with Bun's native `bun:test` runtime.

Use when:
- a Nix module wraps a TypeScript or JavaScript helper
- deterministic mapping logic has a unit-test fixture
- a local service is available for a real E2E test

### Prefetch a fixed-output release artifact

```bash
nix store prefetch-file --json https://example.com/artifact.ext

# Use the unpacked NAR hash expected by fetchzip/fetchFromGitHub-style sources.
nix store prefetch-file --unpack --json https://example.com/source.tar.gz
```

Purpose: get the SRI hash for release tarballs, debs, zip files, or AppImages before wiring them into an override. Add `--unpack` when the Nix fetcher hashes the extracted source tree instead of the downloaded archive bytes.

### Convert an SRI hash to nix32

```bash
nix hash convert --hash-algo sha256 --to nix32 sha256-<sri-hash>
```

Purpose: normalize a prefetch result into the older `sha256 = "..."` form used by existing fixed-output derivations.

### Check which package from an overlay is actually selected

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.niri.package.name'
```

Purpose: confirm whether you are using `niri-stable`, `niri-unstable`, or another overridden package.

### Prefetch a GitHub source hash

```bash
NIX_CONFIG="$NIX_EVAL_FEATURES" nix run nixpkgs#nix-prefetch-github -- --json <owner> <repo> --rev <commit-sha>
```

Purpose: get the `fetchFromGitHub` hash for a pinned commit before updating a fixed-output source.

Use when:
- bumping a GitHub-backed overlay or package source
- you already have a commit SHA and need the matching SRI hash
- updating any derivation that fetches from a specific GitHub revision

### Prefetch an immutable Git source hash

```bash
nix run nixpkgs#nix-prefetch-git -- \
  --url <git-url> \
  --rev <commit-sha> \
  --no-deepClone
```

Purpose: obtain the SRI hash for a `fetchgit` source, including repositories hosted outside GitHub.
Use an immutable commit rather than a branch or moving tag; the command also reports the resolved
revision when an annotated tag is involved.

### Inspect rendered system packages and environment variables

```bash
nix eval --impure --json --expr '
let
  configuration = (builtins.getFlake "/home/vincent/.nixfiles").nixosConfigurations.<host>.config;
in {
  systemPackages = map (package: package.name or "") configuration.environment.systemPackages;
  steamExtraPackages = map (package: package.name or "") configuration.programs.steam.extraPackages;
  matchingVariables = builtins.filter
    (name: builtins.match "<prefix>.*" name != null)
    (builtins.attrNames configuration.environment.variables);
}'
```

Purpose: verify that a package reaches both the system profile and a composed runtime such as
Steam's FHS environment, while confirming that optional feature variables were not applied globally.

### Debug a failing package build

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.pkgs.<pkg>.version' --raw

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.pkgs.<pkg>.meta.position' --raw

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.pkgs.<pkg>'

nix log /nix/store/<failed-derivation>.drv

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix why-depends '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel' '.#nixosConfigurations.'"$HOST"'.pkgs.<pkg>'
```

Purpose: isolate the first broken derivation, inspect the exact nixpkgs source file, and trace why a package is in the host closure.

Use when:
- a switch fails in a single dependency before reaching `toplevel`
- you need to inspect a multilib/FHS package such as `pkgsi686Linux.<pkg>`
- you want the full build log for the failing derivation instead of the truncated switch output

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

## Noctalia Settings Defaults

### Evaluate the rendered Noctalia settings snapshot

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.noctalia-shell.settings' --json
```

Purpose: inspect the effective Noctalia settings after merging the module and filtering defaults.

Use when comparing a pasted export against the local default snapshots in `modules/noctalia/assets/settings-default.json` and `modules/noctalia/assets/settings-widgets-default.json`.

### Evaluate the rendered Noctalia widget settings

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.noctalia-shell.settings.bar.widgets' --json
```

Purpose: inspect the effective bar widget settings as Nix renders them, especially when comparing widget-level defaults.

## DankMaterialShell Settings Defaults

### Compare a DMS JSON export with the upstream settings spec

```bash
DMS_SOURCE=/path/to/DankMaterialShell/quickshell/Common/settings/SettingsSpec.js \
DMS_EXPORT=/path/to/settings.json \
node <<'NODE'
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.env.DMS_SOURCE, "utf8").replace(/^\\.pragma library\\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const settings = JSON.parse(fs.readFileSync(process.env.DMS_EXPORT, "utf8"));
const equal = (left, right) => JSON.stringify(left) === JSON.stringify(right);

for (const [key, value] of Object.entries(settings)) {
  if (!(key in context.SPEC)) {
    console.log("UNKNOWN", key);
  } else if (!equal(value, context.SPEC[key].def)) {
    console.log("DIFF", key, JSON.stringify(value), "default=", JSON.stringify(context.SPEC[key].def));
  }
}
NODE
```

Purpose: identify only persisted DMS values that differ from the checked-out upstream defaults before copying an export into `programs.dank-material-shell.settings`. Treat runtime metadata (for example `lastAppliedIconTheme`) and serialized color objects separately from user preferences.

## Home Manager / Config Evaluation

### Inspect rendered shell initialization and managed config text

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.programs.zsh.initContent' --raw

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."<relative-path>".text' --raw
```

Purpose: inspect the exact shell startup script or text-based XDG configuration Home Manager will render, including ordering-sensitive integrations and generated service/client settings.

Use when:
- a shell integration, keybinding, or autostart hook may be ordered relative to another integration
- checking whether a secret-free config is rendered as intended before activation

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

### Realize and inspect a generated NixOS or Home Manager file source

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.'"$HOST"'.config.environment.etc."<relative-path>".source'
```

Purpose: realize a generated NixOS `/etc` file before opening the returned store path.

Use the Home Manager variants below for files under the user's home directory.

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.file."<home-relative-path>".source'

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.xdg.configFile."<xdg-relative-path>".source'
```

Purpose: realize a `pkgs.formats.*.generate` derivation before opening the returned store path. A plain `nix eval --raw` can return a valid output path that does not exist yet because the source derivation has not been built.

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

### Evaluate a specific Home Manager option subtree

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.<hm.option.path>' --json
```

Purpose: inspect the rendered value of a single Home Manager option or nested attrset, such as `programs.nixcord.config.plugins.<plugin>.enable` or `programs.noctalia-shell.settings`.

Use `--json` for booleans and attrsets; reserve `--raw` for strings and store paths.

### Inspect names from a generated Home Manager list

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval --json '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.<hm.list.option>' \
  --apply 'builtins.map (item: item.name)'
```

Purpose: inspect package-like list options such as enabled Spicetify extensions without trying to serialize derivations and their function-valued attributes directly.

### Inspect a rendered Home Manager activation step

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.activation.<name>.data' --raw
```

Purpose: review the exact shell script Home Manager will execute for a named activation step before applying a switch. Use the equivalent `darwinConfigurations` path for macOS hosts.

### Validate a Home Manager user service after activation

```bash
systemctl --user status <service-name> --no-pager
systemctl --user show <service-name> --property=ExecStart --property=MainPID --property=SubState --no-pager
```

Purpose: confirm the activated unit is running the expected Nix-store wrapper and has a live main process.

For a service with a loopback HTTP health endpoint, add:

```bash
curl --fail --silent --show-error http://127.0.0.1:<port>/<health-path>
```

Use after `nixos-rebuild switch` or a Home Manager activation, before testing clients against the service.

### Probe an authenticated local management endpoint

```bash
SERVICE_HOME="$HOME/.service-name"
ADMIN_TOKEN_FILE="$SERVICE_HOME/admin-api-token"
curl --fail --silent --show-error --max-time 10 \
  -H "x-service-api-key: $(<"$ADMIN_TOKEN_FILE")" \
  "http://127.0.0.1:<port>/<management-path>" | jq .
```

Purpose: inspect a local service's management or capability API while keeping the file-backed administrator token out of command output and shell history.

Use when:
- a generated client configuration depends on live service metadata
- the public health or model endpoint omits administrative capability fields
- you need to compare enabled rows with the service's full configured catalog

### Inspect an Executor MCP registration

```bash
EXECUTOR_TOKEN_FILE="$HOME/.executor/server-control/auth.json"
EXECUTOR_URL="http://127.0.0.1:4789"
MCP_SLUG=<slug>
curl --fail --silent --show-error --max-time 10 \
  -H "Authorization: Bearer $(jq -r '.token' "$EXECUTOR_TOKEN_FILE")" \
  "$EXECUTOR_URL/api/mcp/servers/$MCP_SLUG" | jq .
```

Purpose: inspect a Nix-managed Executor MCP integration and verify that a server or connection has
been removed from the live local catalog without printing the bearer token.

### Probe a local Streamable HTTP MCP proxy

```bash
curl --fail --silent --show-error --max-time 15 \
  -X POST "http://127.0.0.1:<port>/mcp" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}'
```

Purpose: verify that a supervised stdio MCP child is reachable through its local Streamable HTTP proxy and that the proxy returns an MCP initialize response.

## NixOS Host Evaluation

### Evaluate a specific NixOS option subtree

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.<option.path>' --json
```

Purpose: inspect the rendered value of a single NixOS option or nested attrset, such as `services.pipewire` or `home-manager.users.<user>`.

### Realize a generated service configuration file without a full system build

```bash
cd "$REPO" && nix build --impure --no-link --print-out-paths --expr '
let
  flake = builtins.getFlake "path:/home/vincent/.nixfiles";
  pkgs = flake.nixosConfigurations.<host>.pkgs;
  settings = flake.nixosConfigurations.<host>.config.<service-option>;
in
  (pkgs.formats.toml { }).generate "<service-config>.toml" settings
'
```

Purpose: realize the exact store-backed TOML configuration passed to a NixOS service so it can be inspected or used for a runtime smoke test without building the entire system closure.

Related portal checks:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.xdg.portal.extraPortals' --json

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.xdg.portal.config.niri' --json
```

Purpose: verify which xdg-desktop-portal backend packages and session-specific portal defaults are actually active.

### Evaluate rendered filesystem mount options

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.fileSystems."<mountpoint>".options' --json
```

Purpose: confirm the exact `fstab` / systemd mount options NixOS will render for a mountpoint such as `/mnt/windows` before retrying a rebuild or switch.

### Inspect rendered Nix binary cache settings

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.nix.settings.extra-substituters' --json

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.nix.settings.extra-trusted-public-keys' --json
```

Purpose: verify that host-level Cachix or upstream binary caches are rendered before rebuilding or debugging unexpectedly slow builds.

### Compare binary cache impact from an empty temporary store

```bash
cd "$REPO"
tmp_store=$(mktemp -d /tmp/nix-cache-probe-store.XXXXXX)
nix --store "$tmp_store" build --dry-run --no-link \
  '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel' 2>&1 \
  | tee /tmp/nix-cache-probe-current.log
```

Purpose: estimate how many derivations would still build locally on a fresh machine with the current configured substituters.

To test candidate caches without editing the repo first:

```bash
cd "$REPO"
tmp_store=$(mktemp -d /tmp/nix-cache-probe-store-candidate.XXXXXX)
NIX_CONFIG='extra-substituters = https://<cache>.cachix.org
extra-trusted-public-keys = <cache>.cachix.org-1:<public-key>' \
nix --store "$tmp_store" build --dry-run --no-link \
  '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel' 2>&1 \
  | tee /tmp/nix-cache-probe-candidate.log
```

Compare the summary lines:

```bash
rg 'derivations will be built|paths will be fetched' /tmp/nix-cache-probe-*.log
```

### Evaluate the host toplevel derivation

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel.drvPath' --raw
```

Purpose: confirm the full NixOS host still evaluates end-to-end after a module or input change.

### Evaluate or dry-run a nix-darwin host

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix eval '.#darwinConfigurations.<host>.config.system.build.toplevel.drvPath' --raw

cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --dry-run --no-link '.#darwinConfigurations.<host>.config.system.build.toplevel'
```

Purpose: validate a nix-darwin configuration and preview its build closure without switching the macOS host.

Use when: checking a shared Home Manager module on macOS, or isolating the package that introduces an unsupported or failing Darwin dependency.

### Build the host toplevel derivation

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel'
```

Purpose: force a full host build after an option or module change.

### Dry-run the host toplevel build

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build '.#nixosConfigurations.'"$HOST"'.config.system.build.toplevel' --dry-run
```

Purpose: validate evaluation and see which derivations would build without creating a result link or realizing the build.

### Run full flake validation

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" nix flake check
```

Purpose: validate the whole flake and host module graph after a configuration or input change.

For an evaluation-only pass that avoids building check derivations:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" nix flake check --no-build
```

When diagnosing an evaluation failure, include the full Nix stack trace:

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" nix flake check --no-build --show-trace
```

## Runtime Audio Checks

### Inspect the live PipeWire graph

```bash
wpctl status
```

Purpose: verify that the current session exposes the expected input/output devices and that PipeWire, WirePlumber, and portal clients are running.

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

### Run the repo Statix flake check

```bash
cd "$REPO" && NIX_CONFIG="$NIX_EVAL_FEATURES" \
nix build --no-link '.#checks.'"$(nix eval --impure --expr 'builtins.currentSystem' --raw)"'.statix'
```

Purpose: run the repository's Statix check with the repo-specific lint configuration.

### Run Statix directly with the repo config

```bash
cd "$REPO" && nix run nixpkgs#statix -- check --config checks/statix.toml .
```

Purpose: get direct Statix diagnostics locally without building the flake check derivation.

### Format or check all tracked Nix files

```bash
cd "$REPO" && nix fmt
cd "$REPO" && nix fmt -- --ci
```

Purpose: use the flake's `nixfmt-tree` formatter to format the repository, or verify formatting
without modifying files in CI and audit workflows.

For a focused file check without traversing the repository:

```bash
cd "$REPO" && nix run nixpkgs#nixfmt -- --check path/to/file.nix
```

### Find unused Nix declarations

```bash
cd "$REPO" && nix run nixpkgs#deadnix -- .
```

Purpose: detect unused module parameters, derivation lambda arguments, and local bindings that
Statix does not report.

### Check for available formatters

```bash
command -v nixfmt nixfmt-tree alejandra 2>/dev/null
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

### Inspect a Nix-managed user service

```bash
systemctl --user status <service> --no-pager
journalctl --user -u <service> -b --no-pager
journalctl --user -u <service> -b -g 'Error|Fatal|Warning|display|encoder|CAP|KMS|Wayland' --no-pager
```

Purpose: check whether a user service is running and filter the current boot logs for capture, permission, or initialization failures.

Use when a Home Manager or NixOS-managed user service starts but fails at runtime.

### Inspect a NixOS system service

```bash
systemctl status <service>.service --no-pager -l
journalctl -u <service>.service -b --no-pager -n 160
systemctl cat <service>.service
systemctl show <service>.service --property=Environment --property=User --property=SupplementaryGroups --property=ExecStart --no-pager
```

Purpose: identify the actual exit error, generated service environment, and runtime credentials for a failed system service.

### Inspect a transient Wayland session and its environment

```bash
systemctl --user status <session-unit> --no-pager -l
systemctl --user show <session-unit> --property=Environment --property=ExecStart --property=MainPID --property=ControlGroup --no-pager
journalctl --user -u <session-unit> -b --no-pager -n 200
ps -C <compositor> -o user,pid,ppid,stat,etime,args
tr '\0' '\n' < "/proc/<compositor-pid>/environ" | sort
```

Purpose: identify nested compositor layers, Wayland display variables, transient systemd ownership, and the environment inherited by apps launched inside a streamed or remote session.

### Inspect Wayland keysyms in the active compositor

```bash
nix run nixpkgs#wev --
```

Purpose: press a key in the `wev` window and inspect the received XKB keysym, such as `Super_L`, when a remote client or nested compositor may be translating or filtering it.

### Check a network service and its host interfaces

```bash
systemctl is-active <service>.service
ss -ltnup | rg '<port>|<process-name>'
ip -br addr
```

Purpose: confirm that a NixOS-managed network service is running, identify its listening addresses and ports, and verify which host interfaces are available for client access.

### Compare booted and current NixOS generations

```bash
readlink -f /run/booted-system /run/current-system /nix/var/nix/profiles/system
uname -r
modinfo <kernel-module> | rg 'filename|version'
```

Purpose: detect userspace/kernel-module mismatches after a driver update. A reboot is required before testing services that load the newly activated driver userspace against a changed kernel module.

### Inspect a nix-darwin user LaunchAgent

```bash
launchctl print gui/$(id -u)/<label>
plutil -p "$HOME/Library/LaunchAgents/<label>.plist"
```

Purpose: confirm the exact launchd label is loaded and inspect the Nix-managed plist that launchd is using.

### Inspect Sunshine display and input mapping logs

```bash
journalctl --user -u sunshine -b -g 'Resolution|Offset|Logical size|Name:|monitor list|CLIENT|Screencasting|Found monitor|touch|Mouse|absolute|input' --no-pager
```

Purpose: verify which output Sunshine is streaming and which logical offset / size it detected, especially when debugging Moonlight absolute/direct mouse, touch, or stylus mapping issues.

### Inspect and temporarily reposition Niri outputs

```bash
niri msg outputs
niri msg output <output-name> position set 0 0
```

Purpose: check whether a non-zero output offset is causing absolute-input coordinate bugs, and temporarily test a zero-origin output layout without editing the Niri config.

### Check Linux capabilities on wrapped binaries

```bash
getcap /run/current-system/sw/bin/<binary> /etc/profiles/per-user/$USER/bin/<binary> 2>/dev/null
```

Purpose: verify whether a deployed binary or wrapper has capabilities such as `cap_sys_admin`, which some capture or hardware access paths require.

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

### Inspect an application's sandboxed browser environment

```bash
APP_PID=<application-main-pid>
tr '\0' '\n' < "/proc/$APP_PID/environ" | grep -E '^(BROWSER|CHROME|PATH|XDG_DATA_DIRS)='
readlink -f "/proc/$APP_PID/root/usr/bin/xdg-open"
for desktop in brave-browser.desktop google-chrome.desktop; do
  find "/proc/$APP_PID/root" -path "*/share/applications/$desktop" -print
done
```

Purpose: determine whether a sandboxed application sees the host browser desktop entry and which browser-related environment variables or fallback `xdg-open` it can use. An explicit absolute `BROWSER` executable takes precedence over `xdg-open`'s fallback browser list.

## Session-Specific / Less Reusable Commands

These were useful in this session, but are more situational.

### Inspect overlay-provided package names

```bash
nix eval --impure --expr '
let
  f = builtins.getFlake "path:/home/vincent/.nixfiles";
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

### Verify Nix-managed Codex Linux Computer Use

```bash
codex-computer-use-linux doctor
codex-computer-use-linux setup
codex-computer-use-linux windows
codex-computer-use-linux screenshot
```

Purpose: inspect the active session's AT-SPI, portal, compositor, uinput, and
fallback input readiness after the NixOS configuration has been activated.
`setup` changes the current user's accessibility-session state; restart
already-running target applications if their AT-SPI tree remains empty.

### Session-specific smoke tests with visible effects

```bash
niri msg action open-overview
niri msg action focus-window-up
noctalia-shell ipc call cb up
```

Purpose: manual experiments while discovering behavior. These are best used sparingly because they can visibly affect the running session or depend on context.

### Diagnose the active Tailscale peer path

```bash
tailscale status | grep -F '<peer-name>'
tailscale ping --c=20 --until-direct=false '<peer-name>'
tailscale netcheck
tailscale status --json | jq '.Peer[] | select(.DNSName | startswith("<peer-name>")) | {Online, Active, CurAddr, Relay, PeerRelay, LastHandshake, TxBytes, RxBytes}'
```

Purpose: distinguish a direct UDP path (`direct` or a public endpoint in `tailscale ping`) from a DERP path (`relay "<region>"` / `via DERP(...)`) or a Tailscale peer relay (`via peer-relay(...)`). `netcheck` reports NAT and DERP reachability, not the active peer route. Prefer the human-readable `status` and `ping` output over the JSON `Relay` field alone.

### Inspect Niri output modes before attempting a custom mode

```bash
niri msg outputs
niri msg output '<output-name>' --help
```

Purpose: identify the connector and advertised modes before using Niri's custom output mode support. A live mode change has immediate display effects and can blank or damage an out-of-spec physical monitor, so only run these after selecting a safe output and a supported timing.

If an output is known to be safe for the experiment:

```bash
niri msg output '<output-name>' custom-mode '<width>x<height>@<refresh-rate>'
niri msg output '<output-name>' modeline '<vesa-modeline>'
```

Purpose: temporarily request a custom mode or explicit modeline in Niri without editing the declarative configuration. Use `niri msg outputs` afterward to verify the result and restore the declarative mode before ending the experiment.

### Inspect DRM connector modes and EDID

```bash
for connector in /sys/class/drm/card*-*; do
  name=${connector##*/}
  state=$(<"$connector/status")
  printf '%s %s\n' "$name" "$state"
  if [ "$state" = connected ]; then
    cat "$connector/modes"
  fi
done

nix run nixpkgs#edid-decode -- /sys/class/drm/<card>-<connector>/edid
```

Purpose: verify whether a physical or virtual HDMI/DisplayPort sink is currently connected, which modes its EDID advertises, and whether a custom EDID has actually reached the GPU. An empty EDID usually means the connector is disconnected or the sink is powered off.

## Notes

- Many `nix eval` commands in this repo need:

  ```bash
  NIX_CONFIG='extra-experimental-features = nix-command flakes dynamic-derivations'
  ```

  because evaluation of generated Home Manager text can otherwise fail in this environment.

- Prefer validating before rebuilding whenever you touch `programs.niri.settings`, `xdg.configFile."niri/*"`, or Home Manager-managed Niri files.

- When a command touches live compositor state (`niri msg action ...`, `noctalia-shell ipc call ...`), assume it has immediate visible side effects.

### Inspect a Home Manager-managed desktop entry Exec line

```bash
nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.activationPackage'
HM_GEN=$(nix build --no-link --print-out-paths '.#nixosConfigurations.'"$HOST"'.config.home-manager.users.'"$USER"'.home.activationPackage')
sed -n '1,40p' "$HM_GEN/home-path/share/applications/<entry>.desktop"
```

Purpose: verify which absolute binary a `.desktop` file will launch after Home Manager renders overrides.

Use when:
- a launcher (Vicinae, KDE, etc.) opens the wrong app despite selecting the expected desktop entry
- a CLI wrapper such as `code` may be colliding with a packaged `Exec=` line

### Confirm a PATH wrapper still resolves to the intended executable

```bash
command -v <cmd>
readlink -f "$(command -v <cmd>)"
head -n 20 "$(command -v <cmd>)"
```

Purpose: separate CLI wrappers from desktop-entry launch paths when both share the same command name.
