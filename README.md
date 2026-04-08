# nixfiles

Personal NixOS configuration for a single machine, `pc-fixe`, and a single user, `vincent`.

This repository manages both system configuration and Home Manager configuration in one flake-based
setup. It uses a feature-oriented structure, so desktop apps, shell tools, audio, graphics, and
other concerns each live in their own module.

## At a Glance

- Host: `pc-fixe`
- User: `vincent`
- Desktop: KDE Plasma 6
- GPU: NVIDIA
- Config style: Nix flake + flake-parts + Home Manager
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
  pc-fixe/
    default.nix
    configuration.nix
    hardware-configuration.nix
```

## Module Structure

Most feature files expose configuration through one or both of these namespaces:

- `config.flake.modules.nixos.<name>` for system-level NixOS configuration
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
- The home directory should be derived from the username, for example `"/home/${username}"`.
- Home Manager is integrated through the NixOS configuration rather than managed separately.
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

Most inputs follow `nixpkgs` to avoid duplicate evaluations.

## Common Commands

Apply the configuration:

```bash
sudo nixos-rebuild switch --flake .#pc-fixe
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
3. Enable it from `hosts/pc-fixe/default.nix`.

If you want to remove a feature, the main place to change is also `hosts/pc-fixe/default.nix`.

## Extra Documentation

- `AGENTS.md` documents repository conventions in more detail, especially for coding agents.
- `INVESTIGATION_COMMANDS.md` collects useful commands for debugging, validation, and evaluation.
