# NixOS migration: non-flake -> flake + Home Manager

This directory now uses a **basic flake setup** with **Home Manager integrated into NixOS**.

## What these tools are

### Flakes
A flake is a reproducible entrypoint for Nix configuration.

- Pins dependencies (like `nixpkgs`, `home-manager`, `nixcord`) in `flake.lock`.
- Exposes outputs (like `nixosConfigurations.nixos`).
- Lets you run rebuilds with one explicit source (`.`).

### Home Manager
Home Manager manages **user-level configuration** declaratively.

- Good for user packages, shell/editor configs, app configs.
- Works alongside NixOS modules.
- In this setup it is loaded as a NixOS module (single rebuild command updates both system + user config).

## File layout and where to put things

- `flake.nix`: top-level inputs/outputs and module wiring.
- `configuration.nix`: system-level NixOS config (boot, hardware, networking, services, users, etc.).
- `home.nix`: user-level config for `vincent` (user packages, Nixcord settings, user programs).
- `hardware-configuration.nix`: generated hardware config; normally do not edit manually.

Rule of thumb:

- Put machine-wide settings in `configuration.nix`.
- Put per-user settings in `home.nix`.

## What is configured right now

- Flake inputs:
  - `nixpkgs` (`nixos-25.11`)
  - `home-manager` (`release-25.11`)
  - `nixcord`
- Home Manager is integrated via `home-manager.nixosModules.home-manager`.
- `nixcord.homeModules.nixcord` is shared into Home Manager modules.
- `programs.nixcord` is configured in `home.nix` (Discord + Vencord + `fakeNitro`).

## Commands to use (and why)

### 1) Go to your config directory

```bash
cd /home/vincent/.nixfiles
```

Why: all flake commands below are run against this directory (`.`).

### 2) Generate/update lock file

```bash
nix flake update
```

Why: refreshes pinned dependency revisions in `flake.lock`.
Use when you want newer package/module versions.

### 3) Rebuild system from flake

```bash
sudo nixos-rebuild switch --flake .#nixos
```

Why: applies the NixOS configuration named `nixos` from `flake.nix`.
Also applies Home Manager user config because it is integrated as a NixOS module.

### 4) Test without switching boot generation

```bash
sudo nixos-rebuild test --flake .#nixos
```

Why: builds and activates temporarily for validation.
Useful before a full `switch`.

### 5) Show flake outputs

```bash
nix flake show
```

Why: confirms available outputs and names (like `nixosConfigurations.nixos`).

### 6) Inspect what changed in lock file

```bash
git diff flake.lock
```

Why: review dependency updates before committing.

## Typical workflow

```bash
cd /home/vincent/.nixfiles
$EDITOR configuration.nix
$EDITOR home.nix
sudo nixos-rebuild test --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

## Why this is better than your previous setup

- Better reproducibility (pinned inputs via `flake.lock`).
- Clear split between system config and user config.
- Easier future changes (add modules and inputs in one place).

## Notes

- Keep `system.stateVersion` and `home.stateVersion` stable unless you intentionally migrate state.
- If you later want multiple machines/users, add more entries under `nixosConfigurations` and/or more Home Manager user modules.
