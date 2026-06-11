# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Replace OpenCode JSON Transformation With Native Nix Settings

### Context

The shared OpenCode source configuration currently lives in
`modules/coding/assets/opencode.jsonc`. The Home Manager coding module parses that JSON, replaces the
hardcoded Linux home directory, removes Linux-only MCP servers on Darwin, and generates a
platform-specific JSON file:

- `mcp.github` references a token file under the user's home directory.
- `mcp.nixos` depends on the Linux-only `mcp-nixos` package.
- Darwin currently removes both entries because the GitHub token has not been migrated and
  `mcp-nixos` is unavailable there.

This works, but modifying an external JSON-shaped value with `recursiveUpdate` and `removeAttrs`
makes the final configuration less obvious than defining it directly in Nix.

### Desired End State

- Create a reusable OpenCode Home Manager module that works on both Linux and Darwin.
- Define OpenCode settings and each MCP integration as native Nix options so hosts can explicitly
  opt in or opt out instead of having integrations silently removed based on the platform.
- Enable the same useful MCP integrations on both platforms wherever they are supported, including
  provisioning their packages, commands, paths, and secrets appropriately for each platform.
- Keep genuinely platform-specific MCP integrations available only where supported, but represent
  that limitation explicitly and fail with a useful evaluation error when a host enables an
  unsupported integration.
- Derive all home-relative paths from `config.home.homeDirectory`.
- Provision the GitHub MCP token safely on both platforms before enabling that integration.
- Remove `modules/coding/assets/opencode.jsonc` once it is no longer the source of truth.

### Verification

- Evaluate the rendered OpenCode configuration for both `pc-fixe` and `macbook-pro`.
- Confirm neither rendered configuration contains a hardcoded `/home/vincent` or `/Users/vincent`.
- Confirm each host's rendered configuration contains exactly the MCP integrations explicitly
  enabled for that host.
- Confirm shared MCP integrations, including GitHub, work on both Linux and Darwin.
- Confirm enabling an unsupported MCP integration produces a clear Nix evaluation error.
- Confirm the OpenCode systemd service works on Linux.
- Confirm the OpenCode launchd agent remains running on Darwin and
  `curl -fsS http://127.0.0.1:4096/global/health` reports `"healthy":true`.

## Consolidate Shell Configuration Around Zsh

### Context

The Mac login shell is Zsh, but shell configuration is currently split:

- `modules/coding/default.nix` enables Bash and initializes Fnm only for Bash on Linux.
- `modules/darwin/development.nix` contains a Darwin-specific Zsh configuration that still invokes
  Homebrew-managed `fnm` and `hub`.
- Some shell integrations remain in manually managed startup files during the incremental macOS
  migration.

This leaves behavior inconsistent between Linux and Darwin and keeps some development tooling tied
to Bash or Homebrew.

### Desired End State

- Create one reusable Home Manager Zsh feature module shared by Linux and Darwin.
- Move shared aliases and shell integrations into that module.
- Initialize the Nix-managed Fnm package for Zsh on both hosts.
- Migrate Starship, Zoxide, McFly, and other existing interactive integrations into Home Manager
  without losing their current behavior or history.
- Separate Darwin-only integrations such as OrbStack from shared Zsh configuration.
- Remove obsolete Homebrew paths and manually managed Zsh startup content after each replacement is
  tested.
- Remove Bash-only interactive configuration from `hm.coding`; retain Bash only where required for
  compatibility or non-interactive scripts.

### Verification

- New Zsh login and interactive shells start without errors on both hosts.
- `fnm`, Starship, Zoxide, McFly, aliases, completion, autosuggestions, and syntax highlighting
  work on both hosts.
- Darwin shell initialization no longer references `/opt/homebrew/bin/fnm` or
  `/opt/homebrew/bin/hub`.
- Home Manager owns the intended Zsh files without silently discarding existing behavior.
- NixOS rebuilds and Darwin rebuilds both pass before removing old startup-file content.
