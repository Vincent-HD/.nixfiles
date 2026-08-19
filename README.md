# nixfiles

Personal NixOS and macOS configuration for two machines, `pc-fixe` and `macbook-pro`, and a single
user, `vincent`.

This repository manages both system configuration and Home Manager configuration in one flake-based
setup. It uses a feature-oriented structure, so desktop apps, shell tools, audio, graphics, and
other concerns each live in their own module.

## At a Glance

- Hosts: `pc-fixe` (NixOS) and `macbook-pro` (nix-darwin)
- User: `vincent`
- NixOS desktop: KDE Plasma 6 / Niri on NVIDIA
- macOS platform: Apple Silicon with nix-darwin, Home Manager, and declarative Homebrew
- Config style: Nix flake + flake-parts + NixOS/nix-darwin + Home Manager
- Module loading: automatic via `import-tree`

## How This Repo Is Organized

The repo follows a "dendritic" pattern:

- Every `.nix` file under `modules/` and `hosts/` is treated as a flake-parts module.
- Files are imported automatically by `import-tree`, so new modules do not need manual registration.
- Feature modules define reusable pieces of configuration.
- The host composition file decides which features are actually enabled on the machine.

In practice, that means:

- `modules/` contains reusable features such as graphics, audio, browser, coding tools, or desktop setup.
- `hosts/pc-fixe/default.nix` is the composition root that assembles the final system.
- `hosts/macbook-pro/default.nix` is the conservative macOS composition root.
- `hosts/pc-fixe/configuration.nix` contains the base machine configuration.
- `hosts/pc-fixe/hardware-configuration.nix` contains hardware-specific settings.

## Repository Layout

```text
flake.nix
flake.lock
AGENTS.md
INVESTIGATION_COMMANDS.md
modules/
  global-options.nix
  plasma.nix
  niri.nix
  noctalia.nix
  graphics.nix
  sound.nix
  gaming-optimization.nix
  coding.nix
  browser.nix
  discord.nix
  spotify.nix
  bitwarden.nix
  printing.nix
  windows-mounts.nix
  curseforge.nix
  gparted.nix
hosts/
  macbook-pro/
    default.nix
    configuration.nix
  pc-fixe/
    default.nix
    configuration.nix
    hardware-configuration.nix
```

## Module Structure

Most feature files expose configuration through one or both of these namespaces:

- `config.flake.modules.nixos.<name>` for system-level NixOS configuration
- `config.flake.modules.darwin.<name>` for system-level nix-darwin configuration
- `config.flake.modules.homeManager.<name>` for user-level Home Manager configuration

That allows a single feature file to define both machine-wide and user-specific settings when that
makes sense.

Example shape:

```nix
{
  config.flake.modules.nixos.example = { ... }: {
    # NixOS config
  };

  config.flake.modules.homeManager.example = { ... }: {
    # Home Manager config
  };
}
```

Not every module needs both parts.

## Shared Values and Conventions

A few conventions matter when editing this repo:

- The username comes from `config.flake.username`, not from a hardcoded string.
- The home directory should be derived from the username and host platform.
- Home Manager is integrated through the NixOS and nix-darwin configurations rather than managed
  separately.
- Custom option trees should live under `custom.*` when they do not belong to a standard NixOS or
  Home Manager namespace.
- Explicit Nix is preferred over shorthand. Clear bindings are favored over `with`, `inherit`, or
  other shortcuts when they hide where values come from.

## Flake Inputs

The main inputs are:

- `nixpkgs`
- `flake-parts`
- `import-tree`
- `home-manager`
- `code-cursor-nix`
- `nixcord`
- `niri`
- `noctalia`
- `nix-gaming`
- `nix-cachyos-kernel`

Most inputs follow `nixpkgs` to avoid duplicate evaluations.

## Secrets Management

This repository uses [sops-nix](https://github.com/Mic92/sops-nix) for secret management.
Secrets are stored encrypted in `secrets/` and decrypted at activation time.

### Age Key Derivation from SSH

The age private key used by sops-nix is **derived from the SSH private key** (Ed25519)
rather than being a standalone age key. This allows recreating the same age key on any
machine where the SSH private key can be exported.

The Bitwarden SSH Agent can sign with the key but does not make its private material
available to `ssh-to-age`. When needed, explicitly export the private key from Bitwarden,
write it to a protected temporary file, and run:

```bash
# Derive age key from SSH private key
nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt"
```

### Recreating the Age Key on a New Machine

1. Export your SSH private key from Bitwarden (an SSH agent alone is insufficient)
2. Derive the age key (command above)
3. Verify the public key matches `.sops.yaml`:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```
4. The secret files (e.g., `secrets/github-token.yaml`) can now be decrypted

### Updating Secrets After Key Changes

If the age key changes (e.g., new SSH key), update the encrypted files:

```bash
# Update .sops.yaml with the new public key first
sops updatekeys secrets/github-token.yaml
```

### Current Secrets

- `github_token` — GitHub personal access token for the local GitHub MCP server
- `context7_token` — Context7 API key

Both values are encrypted in `secrets/github-token.yaml`; sops-nix materializes them with
mode `0400` below `~/.config/agent-mcp`. On a new Linux or macOS host, create the age key at
`~/.config/sops/age/keys.txt` before the first system activation.

## Common Commands

Apply the configuration:

```bash
sudo nixos-rebuild switch --flake .#pc-fixe
```

Apply the macOS configuration:

```bash
sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the configuration without making it the default boot target:

```bash
sudo nixos-rebuild test --flake .#pc-fixe
```

Update flake inputs:

```bash
nix flake update
```

Inspect flake outputs:

```bash
nix flake show
```

## Editing Tips

If you want to add a new feature:

1. Create a new `.nix` file under `modules/`.
2. Define the NixOS and/or Home Manager module in that file.
3. Enable it from the relevant host composition under `hosts/`.

If you want to remove a feature, change the relevant host composition under `hosts/`.

## Extra Documentation

- `AGENTS.md` documents repository conventions in more detail, especially for coding agents.
- `INVESTIGATION_COMMANDS.md` collects useful commands for debugging, validation, and evaluation.
- `docs/MACOS_INVENTORY.md` records the pre-migration inventory and ownership boundaries for the
  MacBook Pro.
- `docs/MACOS_NIX_RESEARCH.md` records the researched nix-darwin, Home Manager, and Homebrew design
  and migration plan.

## Shared Agent Setup

`modules/agents/` is the declarative home for cross-agent tools and shared Agent Skills.

- Add a skill once in `modules/agents/skills.nix` through `custom.agentSetup.skills`; Home Manager installs it under the Agent Skills
  standard path, `~/.agents/skills`, which Codex and Cursor discover natively; VS Code is configured to use it through
  `chat.agentSkillsLocations`.
- MCPs are deliberately written in each client's native schema: Cursor's global
  `~/.cursor/mcp.json` lives in `modules/agents/cursor.nix`, Codex's lower-precedence
  `/etc/codex/config.toml` lives in `modules/agents/codex.nix`, and VS Code's user-profile
  `mcp.json` lives in `modules/agents/vscode.nix`.
- T3 Code nightly is a pinned desktop package (`packages/t3code`) wired by `modules/agents/t3code.nix`; it drives provider CLIs rather than a client MCP schema.
- File-backed MCP credentials stay outside the Nix store and are decrypted by sops-nix.
- Executable MCPs use pinned Nix packages.
- A home-level `AGENTS.md` gives every AGENTS-aware client the same Nix environment guidance. If a
  command is missing, run it ephemerally with `, <command>` (comma) or
  `nix run nixpkgs#<package> -- <arguments>` instead of installing it globally.

The shared setup currently installs Papercuts, Antislop, RTK, Grill Me, Bro, `reference-repository`, Context7
guidance, Plannotator's skills, `jj-auto-revise`, `jj-resplit-stack`, and `jj-solve-conflict`.
