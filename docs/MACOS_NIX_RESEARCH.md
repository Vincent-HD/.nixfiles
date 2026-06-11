# macOS Nix and Home Manager Research

Research date: 2026-06-08

This document records the recommended design for adding this Mac to the repository. It is based on
the local inventory in [MACOS_INVENTORY.md](./MACOS_INVENTORY.md), current upstream documentation,
and a review of public GitHub configurations.

## Implementation Status

Implemented and evaluated:

- `aarch64-darwin`, nix-darwin, nix-homebrew, and Darwin-specific Home Manager inputs
- `darwinConfigurations.macbook-pro`
- a minimal active composition containing only the Darwin baseline and `hm.browser`
- inactive future Homebrew formula, cask, tap, and MAS declarations
- inactive future Dock/Finder/appearance preferences and Darwin development module
- separate Darwin nixpkgs/Home Manager inputs required by current nix-darwin release matching
- Linux-only custom package outputs restricted to Linux

Not activated:

- the official multi-user Nix 2.34.7 installer is installed; nix-darwin is not activated
- nix-darwin has not changed the system.
- Homebrew has not been migrated or cleaned.
- no package has been installed or removed by the configuration.

Follow [MACOS_BOOTSTRAP.md](./MACOS_BOOTSTRAP.md) and migrate one item at a time using
[MACOS_MIGRATION.md](./MACOS_MIGRATION.md).

## Recommendation

Use this ownership split:

| Concern | Owner |
| --- | --- |
| Nix installation and daemon | Lix installer initially; nix-darwin manages the selected Nix implementation afterward |
| macOS system settings, users, system packages, Homebrew declarations | nix-darwin |
| Homebrew installation and taps | `nix-homebrew`, migrating the existing `/opt/homebrew` installation |
| GUI applications, audio drivers, vendor-integrated utilities | Homebrew casks declared through nix-darwin |
| Mac App Store applications | nix-darwin `homebrew.masApps` |
| Portable CLI packages, Git, shell, dotfiles, user launch agents | Home Manager integrated into nix-darwin |
| MDM/security software and invasive vendor integrations | External/manual owner |

This is intentionally hybrid. Nixpkgs is a strong owner for CLI tools and configuration, while
Homebrew casks are the pragmatic owner for macOS GUI applications and packages that need native
installers, privileged helpers, system extensions, or self-update behavior.

## Why nix-darwin

[nix-darwin](https://github.com/nix-darwin/nix-darwin) is the macOS equivalent of a NixOS system
module graph. It can manage:

- system packages and Nix settings
- users and shells
- macOS `defaults`
- launchd services
- Homebrew formulae, casks, taps, and Mac App Store declarations
- integrated Home Manager generations

nix-darwin exports `flakeModules.default`, which adds `flake.darwinConfigurations` to flake-parts.
That fits this repository's existing explicit flake-parts/dendritic design without replacing it.

The host should be built with `inputs.nix-darwin.lib.darwinSystem`, just as `pc-fixe` is built with
`inputs.nixpkgs.lib.nixosSystem`.

## Why Integrated Home Manager

[Home Manager](https://github.com/nix-community/home-manager) officially supports operation as a
nix-darwin module. Keeping it integrated means one `darwin-rebuild switch` applies the macOS system
and user configuration together, matching the existing NixOS host model.

Darwin-specific Home Manager behavior relevant to this repository:

- Home Manager supports user LaunchAgents through `launchd.agents`.
- With `home.stateVersion >= 25.11`, Darwin applications in `home.packages` are copied to
  `~/Applications/Home Manager Apps` by default so Spotlight can find them.
- Updating copied apps requires macOS App Management permission for the terminal that activates
  Home Manager.
- Linux `systemd.user.services` must be replaced with Darwin `launchd.agents`.
- XDG defaults do not replace macOS LaunchServices/default-app configuration.

The existing `home.stateVersion = "25.11"` should remain stable on both hosts unless there is an
intentional migration.

## Why Keep Homebrew

nix-darwin's built-in
[`homebrew` module](https://nix-darwin.github.io/nix-darwin/manual/#opt-homebrew.enable) generates a
Brewfile and runs Homebrew Bundle during activation. It manages declarations but does not install
Homebrew itself.

[`nix-homebrew`](https://github.com/zhaofengli/nix-homebrew) manages and pins the Homebrew
installation and optionally the taps. It explicitly supports migrating an existing official
Homebrew installation with `autoMigrate = true`.

Use both:

- `nix-homebrew` for `/opt/homebrew` and tap ownership
- nix-darwin `homebrew.*` for formulae, casks, and MAS apps

Do not enable Rosetta Homebrew initially. This Mac has no Rosetta installation and no discovered
Intel-only requirement. Add it only when a real package requires it.

### Safe initial activation policy

Start with:

```nix
homebrew.onActivation = {
  cleanup = "none";
  autoUpdate = false;
  upgrade = false;
};
```

Do not begin with `cleanup = "uninstall"` or `"zap"`. This Mac has casks and packages with
privileged helpers, self-updaters, and overlapping vendor receipts. After every intended Homebrew
package is declared and several activations are verified, move to `cleanup = "check"`. Only
consider `"uninstall"` after resolving every reported extra. Avoid `"zap"` on this work-managed
machine because it removes associated user data.

Homebrew declarations are reproducible as a desired package set, but Homebrew does not give Nix
store-level reproducibility or pin every installed cask version.

## Nix Installer Choice

nix-darwin's current README recommends the Lix installer because it has an automated uninstaller
and supports flake-based setups. Use the Lix installer for the initial implementation unless MDM or
another local constraint blocks it:

<https://lix.systems/install/>

An alternative is the
[Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer), which provides a
macOS-aware installer, repair/uninstall receipt, flakes by default, and macOS upgrade resilience.
Its default Determinate Nix installation requires `nix.enable = false` in nix-darwin, meaning
nix-darwin cannot manage Nix itself. That is a valid design, but it adds a separate Nix ownership
boundary. Do not mix the two models accidentally.

The upstream official Nix installer is not recommended for this host because nix-darwin documents
its lack of an automated uninstaller and complex manual macOS removal process.

No installer should be run until the Darwin configuration evaluates and the bootstrap steps have
been reviewed.

## Proposed Repository Architecture

Keep the dendritic pattern and add Darwin beside NixOS:

```text
flake.nix
hosts/
  pc-fixe/
    ...
  macbook-pro/
    default.nix
    configuration.nix
modules/
  global-options.nix
  darwin/
    homebrew.nix
    macos-defaults.nix
  shell/
    default.nix
  coding/
    default.nix
    linux.nix
    darwin.nix
```

The exact module split should follow actual ownership rather than creating empty platform files.
The important boundaries are:

- `flake.modules.nixos.*`: NixOS-only system features
- `flake.modules.darwin.*`: nix-darwin-only system features
- `flake.modules.homeManager.*`: portable user features or explicitly platform-guarded features
- each host composition root chooses only compatible features

### Required flake changes

Add inputs:

```nix
nix-darwin = {
  url = "github:nix-darwin/nix-darwin";
  inputs.nixpkgs.follows = "nixpkgs-darwin";
};

nix-homebrew.url = "github:zhaofengli/nix-homebrew";
nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

home-manager-darwin = {
  url = "github:nix-community/home-manager";
  inputs.nixpkgs.follows = "nixpkgs-darwin";
};
```

The existing NixOS host remains on `nixos-unstable`. Current nix-darwin `master` requires the
matching `nixpkgs-unstable` branch, so this is an intentional duplicate nixpkgs evaluation rather
than the usual `follows = "nixpkgs"` arrangement. The Darwin-specific Home Manager input follows
the same Darwin package set to avoid a Home Manager/Nixpkgs release mismatch.

Import the nix-darwin flake-parts module:

```nix
inputs.nix-darwin.flakeModules.default
```

Extend supported systems:

```nix
config.systems = [
  "aarch64-darwin"
  "x86_64-linux"
];
```

Use `flake.modules.darwin.*` for reusable Darwin modules. The already imported
`flake-parts.flakeModules.modules` supports arbitrary module classes, including `darwin`.
nix-darwin's own flake module separately defines the `flake.darwinConfigurations` output.

### Proposed Darwin host composition

The Darwin host should:

- set `nixpkgs.hostPlatform = "aarch64-darwin"`
- set `system.primaryUser = config.flake.username`
- set `users.users.${username}.home = "/Users/${username}"`
- keep `system.stateVersion` stable after initial selection
- enable unfree packages consistently with the NixOS host
- integrate `inputs.home-manager-darwin.darwinModules.home-manager`
- set `home.homeDirectory = "/Users/${username}"`
- compose only portable Home Manager modules
- import `nix-homebrew.darwinModules.nix-homebrew`
- migrate the existing Homebrew installation once, then turn off `autoMigrate`

The host name should be stable and repository-friendly, for example `macbook-pro`, rather than
depending on the current Bonjour display name.

## Package Migration Policy

### Move from Homebrew formulae to Home Manager

Prefer Nix/Home Manager for portable CLI tools already represented in the repository or reliably
available on `aarch64-darwin`:

- Git, `gh`, Jujutsu, Vim/Neovim
- `fnm`, `uv`
- AWS CLI, Doppler
- `btop`, `jq`, `hurl`, `ripgrep`, `watch`
- Starship, McFly, Zoxide, The Fuck
- Zsh autosuggestions and syntax highlighting

Migrate a tool only after the Darwin Home Manager generation builds and its shell integration is
active. Then remove its Homebrew declaration. This avoids PATH gaps.

Keep Docker CLI/Compose under Homebrew initially because OrbStack is the runtime and injects native
integration. Revisit after testing Nix-provided clients against OrbStack.

### Keep as Homebrew casks

Prefer casks for:

- GUI apps not well-supported by nixpkgs on Darwin
- apps that self-update
- apps with privileged helpers, drivers, extensions, or native installer behavior
- audio drivers such as BlackHole
- OrbStack, TeamViewer, OBS, Tailscale-adjacent tooling, JetBrains Toolbox, and similar native apps

Avoid installing the same application through both Home Manager and Homebrew. The current Linux
modules for Brave, Bitwarden, Discord, Spotify, Cursor, and VS Code must not be blindly composed on
Darwin when a cask owns the app.

### Keep external

Never use Homebrew cleanup or Nix activation to remove:

- MDM/security software
- Google Drive's privileged integration
- organization-required utilities
- generated Brave web apps
- private SSH keys or credentials

## macOS Defaults Policy

nix-darwin provides typed `system.defaults.*` options for common Finder, Dock, trackpad, keyboard,
clock, screenshot, and other settings. It also provides `CustomUserPreferences` and
`CustomSystemPreferences` for uncovered plist values.

Use typed options first. Add custom preferences only after confirming:

1. the setting is user intent rather than generated state;
2. it is not MDM-controlled;
3. applying it is repeatable;
4. the affected application restart/logout requirement is documented.

Do not copy complete `defaults read` output into Nix. Public issue reports show that some defaults
can be inconsistent across macOS versions or may not update the System Settings UI immediately.
Test each setting on this host.

Initial candidates from the inventory:

- Dock auto-hide and size
- Finder hidden-files, list-view, and path-bar behavior
- dark appearance
- selected trackpad values

## Secrets and Work Machine Constraints

The NixOS host currently uses `sops-nix` as a NixOS module with Linux paths. Darwin secret handling
needs a separate design before composing secret-dependent modules:

- derive paths from `/Users/${username}` or Home Manager's `config.home.homeDirectory`
- decide whether to use a nix-darwin-compatible sops-nix module or Home Manager sops-nix module
- do not read private SSH keys into the Nix store
- preserve MDM and organization security policy

Installing Nix creates a dedicated APFS volume, daemon, build users, and launchd configuration.
Although this Mac is not DEP-enrolled, it is MDM-enrolled. Confirm that local policy allows Nix
before installation.

## Implementation Phases

### Phase 1: Evaluation-only Darwin skeleton

- Add nix-darwin and nix-homebrew inputs.
- Add `aarch64-darwin` and the Darwin reusable module namespace.
- Add the Darwin host with minimal system/user identity.
- Integrate Home Manager with no existing feature modules.
- Evaluate/build the configuration from another Nix-capable machine or after an approved installer
  bootstrap; do not activate Homebrew cleanup.

### Phase 2: Preserve existing Homebrew state

- Declare all current taps, casks, and intended formulae.
- Add MAS declarations for selected App Store apps.
- Enable `nix-homebrew.autoMigrate = true` for the first migration only.
- Keep Homebrew cleanup at `"none"`.
- Build and inspect the generated Brewfile before activation.

### Phase 3: Portable Home Manager baseline

- Add a portable Zsh/shell module.
- Reuse Git/Jujutsu and portable CLI configuration.
- Split Linux-only content out of `hm.coding`.
- Convert the OpenCode user service from `systemd` to `launchd` if it is wanted on macOS.
- Manage selected Kitty, VS Code, and Cursor text configuration.

### Phase 4: macOS defaults and application ownership cleanup

- Add only confirmed macOS preferences.
- Move direct-installed apps with available casks under Homebrew.
- Resolve duplicate ownership such as Bitwarden, IDEs, and session-manager-plugin.
- Change Homebrew cleanup from `"none"` to `"check"`.

### Phase 5: Controlled migration of CLI tools

- Move selected formulae to Home Manager one group at a time.
- Verify shell startup, PATH order, project tooling, OrbStack, and work commands.
- Remove now-unused Homebrew formulae only after successful Nix activation.

## Validation Plan

Before activation:

```bash
nix flake show
nix flake check
nix build .#darwinConfigurations.macbook-pro.system
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.brewfile --raw
nix eval .#darwinConfigurations.macbook-pro.config.home-manager.users.vincent.home.packages --json
```

First activation should be non-destructive:

```bash
darwin-rebuild build --flake .#macbook-pro
sudo darwin-rebuild switch --flake .#macbook-pro
```

After activation, verify:

```bash
darwin-rebuild --list-generations
home-manager generations
brew bundle check
brew services list
launchctl print gui/$(id -u)
```

Also verify the Mac App Store session, OrbStack Docker context, Google Drive integration, MDM
agents, system extensions, shell startup, editor launch/Spotlight behavior, and work-project
commands.

## Sources

Primary sources:

- nix-darwin repository and installation guidance:
  <https://github.com/nix-darwin/nix-darwin>
- nix-darwin option reference, including Homebrew and macOS defaults:
  <https://nix-darwin.github.io/nix-darwin/manual/>
- nix-darwin flake-parts output module:
  <https://github.com/nix-darwin/nix-darwin/blob/master/flake-module.nix>
- Home Manager repository and nix-darwin integration:
  <https://github.com/nix-community/home-manager>
- Home Manager Darwin app copying:
  <https://github.com/nix-community/home-manager/blob/master/modules/targets/darwin/copyapps.nix>
- Home Manager user LaunchAgents:
  <https://github.com/nix-community/home-manager/blob/master/modules/launchd/default.nix>
- nix-homebrew, including existing-install migration:
  <https://github.com/zhaofengli/nix-homebrew>
- Lix installer:
  <https://lix.systems/install/>
- Determinate Nix Installer:
  <https://github.com/DeterminateSystems/nix-installer>
- Determinate Nix and nix-darwin ownership requirement:
  <https://github.com/DeterminateSystems/determinate>

Representative public configurations reviewed for organization and common practice:

- `wimpysworld/nix-config`, a multi-host NixOS/nix-darwin/Home Manager repository:
  <https://github.com/wimpysworld/nix-config>
- `heywoodlh/nix-darwin-flake`, a small nix-darwin/Home Manager/Homebrew example:
  <https://github.com/heywoodlh/nix-darwin-flake>
- `torgeir/nix-darwin`, an Apple Silicon developer setup:
  <https://github.com/torgeir/nix-darwin>
- `AlexNabokikh/nix-config`, a combined NixOS/nix-darwin/Home Manager configuration:
  <https://github.com/AlexNabokikh/nix-config>
