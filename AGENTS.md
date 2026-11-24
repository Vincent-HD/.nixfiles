# nixfiles — Agent Guidelines

Write repository documentation, reports, and other Markdown content in English.

This is a Nix/NixOS/nix-darwin configuration repository for a single user (`vincent`) running on
Linux (`pc-fixe`) and macOS (`vincent-macbook-pro`) hosts. The entire config is written in Nix using the
**dendritic pattern**: every `.nix` file under `modules/` and `hosts/` is a flake-parts module,
auto-imported by `import-tree`. The Linux host runs **KDE Plasma 6** on **NVIDIA** hardware.

---

## Agent References

- `INVESTIGATION_COMMANDS.md` — reusable shell, eval, validation, and debugging command patterns
- `.agents/skills/` — project-scoped Agent Skills discovered by Codex, Cursor, VS Code, and Claude Code's prompt hook
- `.agents/skills/update-investigation-commands/SKILL.md` — project skill for maintaining the investigation command reference
- `reference-repos.md` — only tracks other people's NixOS / nix-darwin / Home Manager configuration repositories. Never add application codebases, packaging repos, skills repos, tooling repos, or other non-config references.

---

## Repository Layout

```
flake.nix                              # Entrypoint: inputs + mkFlake via import-tree ./modules + ./hosts
flake.lock                             # Pinned input versions (auto-generated)
AGENTS.md                              # This file
modules/
  agents/                              # Agent-specific modules: common, skills, Claude, Cursor, Codex, T3 Code, VS Code
  global-options.nix                   # Shared flake-parts options: systems, flake.username
  plasma.nix                           # Inactive KDE Plasma 6 alternative (NixOS + HM)
  niri.nix                             # Active Niri compositor + greetd session (NixOS + HM)
  dms/dms.nix                          # Active DankMaterialShell integration and plugins
  noctalia/noctalia.nix                # Inactive legacy Noctalia v4 alternative
  graphics.nix                         # NVIDIA GPU (NixOS)
  sound.nix                            # PipeWire audio (NixOS)
  coding/                              # Editors, Git, Jujutsu, and Nix tooling
  command-line/                        # Shared Zsh configuration and CLI tools
  packages.nix                         # Standalone package and app outputs
  browser.nix                          # Brave (HM)
  equibop.nix                          # Equibop with Equicord settings and macOS cask
  craft-apps.nix                       # ArtCraft apps (PhotoCraft, PdfCraft, WordCraft) with per-app toggles and file associations
  open-pencil.nix                      # OpenPencil design editor + MCP server and ACP agent adapters
  libreoffice.nix                      # LibreOffice (Qt6 build + render profiles on Linux, cask on macOS); default for spreadsheets
  kdenlive.nix                         # Kdenlive video editor (HM on Linux, cask on macOS)
  spotifast.nix                        # Spotifast (HM)
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
  macbook-pro/
    default.nix                        # Composition root: assembles darwinConfigurations."vincent-macbook-pro"
    configuration.nix                  # Base nix-darwin config
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
| `niri`           | `github:sodiboo/niri-flake`           | Niri compositor (optional session)   |
| `noctalia`       | `github:noctalia-dev/noctalia-shell`  | Noctalia shell + HM module           |

All inputs except `flake-parts`, `import-tree`, and `code-cursor-nix` follow `nixpkgs` to avoid
duplicate evaluations.

Equibop uses the nixpkgs package on Linux and the Homebrew cask on macOS; Home Manager manages its
Equicord settings on both hosts.

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

### Validate affected hosts

When a change touches a shared module, shared package, flake input, or anything imported by both
hosts, validate both configured systems:

```bash
nix eval .#nixosConfigurations.pc-fixe.config.system.build.toplevel.drvPath --raw
nix eval .#darwinConfigurations.vincent-macbook-pro.system --raw
```

For Linux-only changes, validating `.#nixosConfigurations.pc-fixe` is enough. For Darwin-only
changes, validate `.#darwinConfigurations.vincent-macbook-pro`.

---

## Commit Messages

Commit subjects and Jujutsu revision descriptions generated for this repository must use Conventional
Commits: `<type>[optional scope][!]: <imperative description>`. Use a lowercase, specific type and
description; do not create `WIP`, `update`, `changes`, or other vague subjects.

---

## Important Notes for Agents

- **Be as explicit as possible in Nix.** Avoid shorthand that hides where values come from or where
  they are exported to.
- When adding new config, include a small comment above it that briefly explains what it does.
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
- **Pinned packages update through one path.** `nix run .#update-pins` refreshes every flake input and every
  flake package; read `docs/UPDATE_COMMANDS.md` before adding or changing a pinned package. Never hand-edit
  hashes and never add a per-package updater script (`update.ts`, shell updaters, regex rewrites of `.nix`).
- **Packages not in nixpkgs live in `packages/<name>/default.nix`** (a standalone derivation, `finalAttrs`
  pattern) exposed in `modules/packages.nix`; modules consume the flake package or `pkgs.callPackage` it.
- **Every package under `packages/` declares `passthru.updateScript = packageUpdater.script { ... }`** (see
  `packages/package-updater`) using the smallest knob that works: `nixUpdateArgs` (nix-update finds the
  version), then `latestVersion` (a shell command printing it), then a short `postUpdate` Bun hook for coupled
  artifacts. Multi-platform packages put every version-following fetch in `passthru.sources` so one host
  refreshes all platform hashes. Keep the version and every hash as literals in the `file` given to the script.
- **Anything intentionally not auto-updated gets a hold** in `scripts/update-pins.json` with a reason that
  says how to update it by hand. Flake inputs need no registration: they are discovered from `flake.lock`, and
  inputs pinned to a commit in `flake.nix` are skipped automatically.
- **Run `nix run .#update-pins -- --check` after touching packages, holds, or inputs**; it fails when a
  package lacks the shared updater or a hold names nothing. Do not add package or host builds to the update
  run; each host validates its own configuration.
- **Build every shell script with `pkgs.writeShellApplication`**, never `writeShellScript`,
  `writeShellScriptBin`, `writeScript(Bin)`, or an executable `home.file`. It pins bash, adds
  `errexit`, `nounset`, and `pipefail`, and runs shellcheck at build time. List the commands a
  script calls in `runtimeInputs` (keep absolute store paths only for commands run under `sudo`,
  which resets `PATH`), reference the result with `lib.getExe`, and keep long scripts in the
  module's `assets/` through `builtins.readFile`. Fix shellcheck findings rather than excluding
  them, and use `bashOptions` only to keep a script's deliberate mode. The `shell-script-builders`
  flake check enforces this in `modules/` and `hosts/`; build-time stubs inside derivations under
  `packages/` and Agent Skill resource scripts are exempt.
- When adding a new external flake input, add `inputs.<name>.follows = "nixpkgs"` when the input
  supports it, to avoid duplicate nixpkgs evaluations.
- Keep `system.stateVersion` and `home.stateVersion` stable unless intentionally migrating state.
- **Add cross-client Agent Skills through `custom.agentSetup.skills` in `modules/agents/skills.nix` (or a
  contributing feature module).** Home Manager installs each entry under `~/.agents/skills`, which
  Codex and Cursor discover natively, while VS Code is configured through
  `chat.agentSkillsLocations`. Do not duplicate them under
  `~/.codex/skills` or `~/.cursor/skills`, and do not manage
  any tool's built-in skill directory.
  Claude Code's `programs.claude-code.skills` exposes the same registered sources under
  `~/.claude/skills`; its prompt hook discovers project `.agents/skills` metadata.
- **Keep MCP definitions explicit in each client's native schema.** Maintain Cursor in
  `modules/agents/cursor.nix`, Codex in `modules/agents/codex.nix`, and VS Code in
  `modules/agents/vscode.nix`; Claude Code uses `programs.claude-code.mcpServers` in
  `modules/agents/claude.nix`. Repeating the small
  server list is preferred over a normalizing abstraction. Use pinned executable paths and
  retrieve secret values at process startup through the Bitwarden runtime helper.
- **Use the generic Bitwarden runtime-secret convention.** Name Login items
  `secret--<resource>--<purpose>` in lowercase kebab-case and put the value in Password. Use the
  `secret--` prefix to distinguish program credentials from personal logins, regardless of
  consumer type. Declare each item and its destinations in the `runtimeSecrets` list in
  `modules/bitwarden.nix`. Omitting `destinations` writes a persistent file under
  `~/.local/state/bitwarden-secrets/` by default. `destinations.environmentVariable` injects the
  value into a managed child process; `destinations.file` configures a file path and optional
  argument. Both can be set for the same item. Run `bw-secret sync` to refresh the local copies.
  They are plaintext, mode `0400`, and intentionally persist across reboots; never put their values
  in Nix expressions or the Nix store.
- **Keep copied third-party skills as local snapshots** when they are not a versioned upstream
  repository. Do not add flake inputs or update automation for Grill Me, Reference Repository,
  or Bro (wait-what snapshot from mattpocock/skills, without CONTEXT.md).
- **`reference-repos.md` is NixOS-config-only.** Only list other people's NixOS / nix-darwin / Home Manager
  configuration repositories. Never add application, packaging, skills, tooling, or template repos.

### Local web UI service registry

- **Keep `modules/dms/plugins/service-hub/services.json` as the source of truth** for human-facing web
  interfaces exposed by this setup. Each entry includes an `id`, `name`, short `description`, Material
  Symbols `icon` (or a direct image URL such as a GitHub `raw.githubusercontent.com` URL), display-only
  `port`, and launch `url`.
- When adding or changing a locally bound human-facing HTTP(S) UI, update the registry. Prefer a
  `localhost` launch URL when the service enforces loopback-origin authentication; add a custom
  `/etc/hosts` alias only when the service explicitly supports non-loopback `Host` headers.
- Keep API-only, MCP, CDP, and internal control endpoints out of the registry. Services on another host
  should use that host's LAN address in `/etc/hosts` instead of `127.0.0.1`.

---

## Agent Learnings

### Noctalia JSON defaults

When the user pastes a Noctalia settings export, compare it against the upstream defaults before writing anything into `modules/noctalia/noctalia.nix`.

- Local snapshots to check first:
  - `modules/noctalia/assets/settings-default.json`
  - `modules/noctalia/assets/settings-widgets-default.json`
- Check `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/Commons/Settings.qml` for the real default values.
- Check `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/Assets/settings-default.json` for the generated top-level defaults.
- Check `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/Assets/settings-widgets-default.json` for widget defaults.
- Use `nix eval .#nixosConfigurations.pc-fixe.config.home-manager.users.vincent.programs.noctalia-shell.settings --json` to confirm the rendered Nix matches only the non-default values.
- Prefer omitting values that match upstream defaults, even if they appear in the export JSON.
- The `noctalia` skill in `.agents/skills/noctalia/SKILL.md` captures this workflow.

### import-tree requires git-tracked files

When creating new module directories (e.g., moving `coding.nix` to `coding/default.nix`),
**the files must be tracked by git** before `import-tree` will discover them. If you see
`attribute 'coding' missing` errors during `nix flake check`, run:

```bash
git add modules/coding/
```

This is because `import-tree` operates on the git tree, not the working directory.

### Module organization with assets

When a module needs to include static files (configs, scripts, etc.), organize them in a
subdirectory:

- When static instructions, configuration, or scripts become long, prefer a checked-in asset
  file in the owning module's `assets/` directory instead of embedding a large heredoc in `.nix`.
- Keep Nix focused on wiring and dynamic values; use Nix variables and interpolation to inject
  those values into assets when needed.

```
modules/agents/
├── common.nix
└── assets/
    └── common-agent-instructions.md
```

Reference assets using relative paths:

```nix
home.file."AGENTS.md".text = builtins.readFile ./assets/common-agent-instructions.md;
```

This keeps related files together and avoids cluttering the top-level `modules/` directory.
