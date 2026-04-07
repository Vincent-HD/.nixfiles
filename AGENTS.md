# nixfiles — Agent Guidelines

This is a NixOS configuration repository for a single user (`vincent`) running on a single host
(`pc-fixe`). The entire config is written in Nix using the **dendritic pattern**: every `.nix` file
under `modules/` is a flake-parts module, auto-imported by `import-tree`. The system runs
**KDE Plasma 6** on **NVIDIA** hardware.

---

## Repository Layout

```
flake.nix                              # Entrypoint: inputs + mkFlake via import-tree ./modules
flake.lock                             # Pinned input versions (auto-generated)
AGENTS.md                              # This file
modules/
  helpers.nix                          # Shared options: systems, flake.username
  flake-modules.nix                    # Imports flake-parts modules + home-manager flake module
  hosts/
    main/
      default.nix                      # Composition root: assembles nixosConfigurations."pc-fixe"
      configuration.nix                # Base NixOS config (boot, networking, locale, user, nix)
      hardware-configuration.nix       # Hardware-specific config (disks, CPU, kernel modules)
  features/
    plasma.nix                         # KDE Plasma 6 + SDDM + Kate (NixOS + HM)
    graphics.nix                       # NVIDIA GPU (NixOS)
    sound.nix                          # PipeWire audio (NixOS)
    coding.nix                         # VSCode, Cursor, OpenCode, Neovim, Vim, Git (NixOS + HM)
    browser.nix                        # Brave (HM)
    discord.nix                        # Nixcord with Vencord (HM)
    spotify.nix                        # Spotify (HM)
    bitwarden.nix                      # Bitwarden Desktop (HM)
    printing.nix                       # CUPS printing (NixOS)
```

---

## Architecture: The Dendritic Pattern

### Core Concepts

1. **Every `.nix` file is a flake-parts module.** The `import-tree` input recursively discovers all
   `.nix` files under `modules/` and passes them as imports to `flake-parts.lib.mkFlake`. Drop a new
   file in `modules/` and it is automatically loaded -- no manual registration needed.

2. **Feature-oriented organization.** Each feature file can define both NixOS system-level config
   and Home Manager user-level config for the same concern in a single file:

   ```nix
   {
     flake.modules.nixos.<name> = { ... }: { /* system config */ };
     flake.modules.homeManager.<name> = { ... }: { /* user config */ };
   }
   ```

   Not every feature needs both -- omit the namespace that doesn't apply.

3. **Composition root.** The host file (`modules/hosts/main/default.nix`) is where features are
   cherry-picked. It creates `flake.nixosConfigurations."pc-fixe"` by listing which `nixos.*` and `hm.*`
   modules to include. To add or remove a feature from a host, edit only this file.

4. **Shared values via `config.flake.*`.** The username is accessed as `config.flake.username`
   (defined in `helpers.nix`). No `specialArgs` threading is needed.

### Module Namespaces

| Namespace                          | Purpose                                            | Accessed via                              |
| ---------------------------------- | -------------------------------------------------- | ----------------------------------------- |
| `flake.modules.nixos.<name>`       | NixOS system-level module                          | `config.flake.modules.nixos.<name>`       |
| `flake.modules.homeManager.<name>` | Home Manager user-level module                     | `config.flake.modules.homeManager.<name>` |
| `flake.nixosModules.<name>`        | Standalone NixOS module (used for hardware config) | `inputs.self.nixosModules.<name>`         |
| `flake.nixosConfigurations.<host>` | Complete NixOS system configuration                | `nixos-rebuild --flake .#<host>`          |

### Flake Inputs

| Input            | URL                                   | Purpose                              |
| ---------------- | ------------------------------------- | ------------------------------------ |
| `nixpkgs`        | `github:NixOS/nixpkgs/nixos-unstable` | Package repository                   |
| `flake-parts`    | `github:hercules-ci/flake-parts`      | Flake framework (composable modules) |
| `import-tree`    | `github:vic/import-tree`              | Auto-import all `.nix` files         |
| `home-manager`   | `github:nix-community/home-manager`   | User-level config management         |
| `code-cursor-nix`| `github:jacopone/code-cursor-nix`     | Cursor editor package                |
| `nixcord`        | `github:FlameFlag/nixcord`            | Discord + Vencord (HM module)        |

All inputs except `flake-parts`, `import-tree`, and `code-cursor-nix` follow `nixpkgs` to avoid
duplicate evaluations.

---

## Build & Apply Commands

### Apply the configuration

```bash
sudo nixos-rebuild switch --flake .#pc-fixe
# or
sudo nixos-rebuild test --flake .#pc-fixe
```

### Update flake inputs

```bash
nix flake update
```

### Show flake outputs

```bash
nix flake show
```

---

## Important Notes for Agents

- **Never hardcode the username** -- always use `config.flake.username` (resolves to `"vincent"`).
- **Never hardcode the home directory** -- derive it from the username: `"/home/${username}"`.
- **`allowUnfree = true`** is set system-wide in `modules/hosts/main/configuration.nix`.
- **Home Manager is integrated as a NixOS module** (`inputs.home-manager.nixosModules.home-manager`).
  All HM config goes through `home-manager.users.${username}` in the host composition root.
- **The `flake.modules.*` namespaces** are enabled by importing `flake-parts.flakeModules.modules`
  and `home-manager.flakeModules.home-manager` in `modules/flake-modules.nix`.
- When adding a new external flake input, add `inputs.<name>.follows = "nixpkgs"` when the input
  supports it, to avoid duplicate nixpkgs evaluations.
- Keep `system.stateVersion` and `home.stateVersion` stable unless intentionally migrating state.
