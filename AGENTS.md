# nixfiles — Agent Guidelines

This is a NixOS configuration repository for a single user (`vincent`) running on a single host
(`pc-fixe`). The entire config is written in Nix using the **dendritic pattern**: every `.nix` file
under `modules/` and `hosts/` is a flake-parts module, auto-imported by `import-tree`. The system runs
**KDE Plasma 6** on **NVIDIA** hardware.

---

## Repository Layout

```
flake.nix                              # Entrypoint: inputs + mkFlake via import-tree ./modules + ./hosts
flake.lock                             # Pinned input versions (auto-generated)
AGENTS.md                              # This file
modules/
  global-options.nix                   # Shared flake-parts options: systems, flake.username
  plasma.nix                           # KDE Plasma 6 + SDDM + Kate (NixOS + HM)
  graphics.nix                         # NVIDIA GPU (NixOS)
  sound.nix                            # PipeWire audio (NixOS)
  coding.nix                           # VSCode, Cursor, OpenCode, Neovim, Vim, Git (NixOS + HM)
  browser.nix                          # Brave (HM)
  discord.nix                          # Nixcord with Vencord (HM)
  spotify.nix                          # Spotify (HM)
  bitwarden.nix                        # Bitwarden Desktop (HM)
  printing.nix                         # CUPS printing (NixOS)
  windows-mounts.nix                   # Windows / WSL mounts custom module (NixOS)
  curseforge.nix                       # CurseForge AppImage wrapper (HM)
  gparted.nix                          # GParted system package (NixOS)
hosts/
  pc-fixe/
    default.nix                        # Composition root: assembles nixosConfigurations."pc-fixe"
    configuration.nix                  # Base NixOS config (boot, networking, locale, user, nix)
    hardware-configuration.nix         # Hardware-specific config (disks, CPU, kernel modules)
```

---

## Architecture: The Dendritic Pattern

### Core Concepts

1. **Every `.nix` file under `modules/` and `hosts/` is a flake-parts module.** The `import-tree`
   input recursively discovers those files and passes them as imports to `flake-parts.lib.mkFlake`.
   Drop a new file in one of those directories and it is automatically loaded -- no manual
   registration needed.

2. **Feature-oriented organization.** Each feature file can define both NixOS system-level config
   and Home Manager user-level config for the same concern in a single file:

   ```nix
   {
     config.flake.modules.nixos.<name> = { ... }: { /* system config */ };
     config.flake.modules.homeManager.<name> = { ... }: { /* user config */ };
   }
   ```

   Not every feature needs both -- omit the namespace that doesn't apply.

3. **Composition root.** The host file (`hosts/pc-fixe/default.nix`) is where features are
   cherry-picked. It creates `flake.nixosConfigurations."pc-fixe"` by listing which `nixos.*` and `hm.*`
   modules to include. To add or remove a feature from a host, edit only this file.

4. **Shared values via `config.flake.*`.** The username is accessed as `config.flake.username`
   (declared in `modules/global-options.nix` and assigned in `hosts/pc-fixe/configuration.nix`).
   No `specialArgs` threading is needed.

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

- **Be as explicit as possible in Nix.** Avoid shorthand that hides where values come from or where
  they are exported to.
- **Do not use implicit flake-parts top-level exports** such as bare `flake.*` at module top level.
  Prefer explicit `config.flake.*` or `config = { flake.* = ...; };`.
- **Avoid `with`, `inherit`, and other convenience shorthand** when a direct explicit binding is
  clearer. Prefer `home.packages = [ pkgs.foo pkgs.bar ];` over `with pkgs; [ foo bar ]`, and
  prefer `inputs = inputs;` over `inherit inputs;`.
- **When defining reusable repo-specific values or module trees, choose the most explicit layer**
  available so future readers can see whether something belongs to flake-parts config, NixOS
  module config, Home Manager config, or a custom option tree.
- **Never hardcode the username** -- always use `config.flake.username` (resolves to `"vincent"`).
- **Never hardcode the home directory** -- derive it from the username: `"/home/${username}"`.
- **`allowUnfree = true`** is set system-wide in `hosts/pc-fixe/configuration.nix`.
- **Home Manager is integrated as a NixOS module** (`inputs.home-manager.nixosModules.home-manager`).
  All HM config goes through `home-manager.users.${username}` in `hosts/pc-fixe/default.nix`.
- **The `flake.modules.*` namespaces** are enabled directly in `flake.nix` by importing
  `flake-parts.flakeModules.modules` and `home-manager.flakeModules.home-manager`.
- **Use `custom.*` for user-defined option trees** that do not belong under a standard NixOS/Home
  Manager namespace such as `services.*`, `programs.*`, `users.*`, or `hardware.*`. Example:
  `options.custom.windowsMounts` and `config.custom.windowsMounts`.
- When adding a new external flake input, add `inputs.<name>.follows = "nixpkgs"` when the input
  supports it, to avoid duplicate nixpkgs evaluations.
- Keep `system.stateVersion` and `home.stateVersion` stable unless intentionally migrating state.
