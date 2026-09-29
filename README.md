# nixfiles

Personal NixOS and macOS configuration for two machines, `pc-fixe` and `macbook-pro`, and a single
user, `vincent`.

This repository manages both system configuration and Home Manager configuration in one flake-based
setup. It uses a feature-oriented structure, so desktop apps, shell tools, audio, graphics, and
other concerns each live in their own module.

## At a Glance

- Hosts: `pc-fixe` (NixOS) and `macbook-pro` (nix-darwin)
- User: `vincent`
- NixOS desktop: Niri + DankMaterialShell on NVIDIA; Plasma and Noctalia remain available as inactive alternatives
- macOS platform: Apple Silicon with nix-darwin, Home Manager, and declarative Homebrew
- Config style: Nix flake + flake-parts + NixOS/nix-darwin + Home Manager
- Module loading: automatic via `import-tree`

Inactive fallbacks are kept deliberately for possible future use: Plasma as an alternative desktop,
Noctalia v4 as an alternative shell, and Moonshine as an alternative remote-session host. They are
not part of the active composition and must be re-evaluated before reactivation.

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
  agents/
    common.nix
    skills.nix
    codex.nix
    cursor.nix
    t3code.nix
    vscode.nix
  coding/
    default.nix
    editors.nix
    git.nix
    jujutsu.nix
    nix-tools.nix
  command-line/
    default.nix
    assets/
  darwin/
  dms/
    dms.nix
    assets/
  noctalia/                    # Inactive legacy alternative
  global-options.nix
  packages.nix
  checks.nix
  plasma.nix
  niri.nix
  graphics.nix
  sound.nix
  lsfg-vk.nix
  gaming-optimization.nix
  browser.nix
packages/                     # Standalone pinned derivations
scripts/                      # Update runner and DMS persistence helper
docs/                         # Operational references and research
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

The main framework and host inputs are:

- `nixpkgs`
- `flake-parts`
- `import-tree`
- `home-manager`
- `home-manager-darwin`
- `nix-darwin`
- `code-cursor-nix`
- `nixcord`
- `niri`
- `dms`
- `nix-gaming`
- `nix-cachyos-kernel`

Pinned DMS plugin sources, Agent Skill sources, and selected application flakes are also tracked in
`flake.lock`. Most compatible inputs follow the host package set to avoid duplicate evaluations;
`nix-cachyos-kernel` intentionally keeps its own nixpkgs revision for binary-cache compatibility.

## Bitwarden Secrets

Nix declares which Bitwarden Login items are needed and where each value goes. Home Manager writes
the non-secret manifest to `~/.config/bw-secret/secrets.json`; secret values stay out of the Nix
store. `bw-secret sync` refreshes persistent, mode-0400 local files from Bitwarden. Programs can
start from those local files after reboot without unlocking Bitwarden.

### Convention

- Name each Bitwarden **Login** item `secret--<resource>--<purpose>` using lowercase kebab-case.
  The `secret--` prefix distinguishes program credentials from personal logins; the remaining name
  works for any resource or consumer. Examples: `secret--github--personal-access-token`,
  `secret--context7--api-key`, `secret--nas--ssh-key`. Put the secret value in **Password**;
  username can stay empty. Keep the item in a vault available to the machines that need it.
- Declare each source item in the `runtimeSecrets` list in `modules/bitwarden.nix`. Omitting
  `destinations` writes a file at `~/.local/state/bitwarden-secrets/<item>` by default. Add
  `destinations.environmentVariable` to inject the value into the managed program's environment,
  `destinations.file` to configure a file output, or both to enable both outputs.

The destination choice is part of each declaration:

```nix
runtimeSecrets = [
  {
    item = "secret--service--file-only";
  }
  {
    item = "secret--service--env-only";
    destinations.environmentVariable = "SERVICE_API_KEY";
  }
  {
    item = "secret--service--both";
    destinations.environmentVariable = "SERVICE_CREDENTIALS";
    destinations.file = {
      path = "${config.home.homeDirectory}/.config/service/credentials";
      argument = "--credentials-file";
    };
  }
];
```

The first two items use the default local path at
`~/.local/state/bitwarden-secrets/<item>`; `bw-secret exec` also exports the second item's value to
its program. The third writes to the configured file and also sets the variable when its program
starts; if `argument` is set, `bw-secret exec` adds that file option and path to the command.

### Sync and startup

On each machine:

1. Create the needed Bitwarden Login items yourself, using the names declared in Nix.
2. Apply the Nix configuration so it installs the manifest.
3. Sign in to the Bitwarden CLI once with `bw login` (separate from the Desktop app).
4. Run `bw-secret sync`. If the CLI has no session in the current environment, it prompts for the
   master password, refreshes all declared items, and writes them locally with mode `0400`.

If you previously used the session-bridge version of this helper, run `bw-secret lock` once to
remove its saved `BW_SESSION` from the user service manager.

The command to start a secret-backed program is `bw-secret exec --item ITEM -- PROGRAM ...`.
Executor uses this for GitHub and Context7. The helper reads the local cache and sets any declared
environment variable only for that child process. File destinations remain available at their
configured paths.

No unlock is needed at computer startup. When you add or rotate an item in Bitwarden, run
`bw-secret sync` on each machine that uses it. The local copy survives reboot, and an already-running
program needs a restart to receive a refreshed environment value.

The local files are decrypted plaintext, owned by the user, and mode `0400`; the state directory is
mode `0700`. They are intentionally persistent so startup does not depend on an interactive vault
unlock. Protect them with the machine's normal disk security. Secret values are never put in Nix
expressions, the generated manifest, or the Nix store.

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

Format all tracked Nix files and verify formatting without modifying them:

```bash
nix fmt
nix fmt -- --ci
```

Evaluate all flake outputs and run the registered build checks:

```bash
nix flake check
```

Review or run the data-driven pin update registry:

```bash
nix run .#update-pins -- --list
nix run .#update-pins -- --dry-run
```

Persist DMS settings edited in the running shell:

```bash
persist-dms --dry-run  # preview the non-default settings diff
persist-dms            # write and commit only modules/dms/assets/generated-settings.json
persist-dms --watch    # keep watching and commit each debounced change
```

The command reads DMS's in-memory settings through IPC and compares them with the
`SettingsSpec.js` shipped by the installed DMS package. Runtime serialization artifacts and
settings managed directly in `dms.nix` are excluded. Use `nix run .#persist-dms -- ...` before
the command has been installed into the user profile.

## Editing Tips

If you want to add a new feature:

1. Create a new `.nix` file under `modules/`.
2. Define the NixOS and/or Home Manager module in that file.
3. Enable it from the relevant host composition under `hosts/`.

If you want to remove a feature, change the relevant host composition under `hosts/`.

## Extra Documentation

- `AGENTS.md` documents repository conventions in more detail, especially for coding agents.
- `INVESTIGATION_COMMANDS.md` collects useful commands for debugging, validation, and evaluation.
- `docs/MACOS_MIGRATION.md` is the current live-inventory and application-ownership plan for the
  MacBook Pro.
- `docs/COMMAND_LINE_OVERVIEW.html` is a visual map of the shared terminal environment.
- `docs/WIFI_AUDIO_STREAMING.md` covers Android-to-desktop streaming and host setup.
- `docs/UPDATE_COMMANDS.md` documents every registered pinned package and flake-input update.
- `docs/NIX_CLI_CHEATSHEET.md` describes the repository's validation ladder and Nix tooling.

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
- MCP credentials are loaded from the local Bitwarden sync files at process startup and passed only
  to the child process environment.
- Executable MCPs use pinned Nix packages.
- A home-level `AGENTS.md` gives every AGENTS-aware client the same Nix environment guidance. If a
  command is missing, run it ephemerally with `, <command>` (comma) or
  `nix run nixpkgs#<package> -- <arguments>` instead of installing it globally.

The shared setup currently installs Papercuts, RTK, Grill Me, Bro, FRR, `reference-repository`, Context7
guidance, Plannotator's skills, `jj-auto-revise`, `jj-resplit-stack`, and `jj-solve-conflict`.
