# macOS Inventory

Snapshot date: 2026-06-08

This is a read-only inventory made before adding macOS support to this repository. It records the
state that a future nix-darwin and Home Manager configuration must preserve or intentionally
replace. It excludes secrets, serial numbers, hardware UUIDs, and the MDM server address.

## Executive Summary

- Hardware: MacBook Pro `Mac15,7`, Apple M3 Pro, 12 CPU cores, 18 GB RAM, Apple Silicon
- Platform: `aarch64-darwin`
- OS: macOS 15.5, build `24F74`
- User: `vincent`, home `/Users/vincent`, login shell `/bin/zsh`, administrator
- Security: FileVault, Gatekeeper, System Integrity Protection, and application firewall enabled
- Management: user-approved MDM enrollment with organization-managed security software
- Nix: not installed; `/nix` does not exist
- Homebrew: installed at `/opt/homebrew`, Homebrew 5.1.15
- Xcode: Command Line Tools 16.2 installed; full Xcode is not installed
- Rosetta 2: not installed
- Printers: none configured

At the time of this snapshot, the repository was not applicable on this machine. It only exported
an `x86_64-linux` NixOS host, and its only Home Manager composition used `/home/vincent`. The
subsequent implementation is documented in [MACOS_NIX_RESEARCH.md](./MACOS_NIX_RESEARCH.md).

## Ownership Model

The Mac currently has four software ownership categories:

| Owner | Current role | Future declarative owner |
| --- | --- | --- |
| Homebrew | Most CLI tools, most third-party GUI apps, fonts, and audio drivers | nix-darwin `homebrew.*`, backed by the existing Homebrew installation |
| Mac App Store | Apple creative/productivity apps, Bitwarden, GIPHY Capture, Tailscale | nix-darwin `homebrew.masApps`, where useful |
| Vendor/manual installer | Google Drive, Slack, Arc, HTTPie, Zwift, and a few others | Prefer a Homebrew cask when available; otherwise document as manual |
| Organization/MDM | SentinelOne, CrowdStrike Falcon, Fleet/Orbit, Bootstrap Buddy, Escrow Buddy | Must remain externally managed |

Nix and Home Manager should become a fifth category for portable CLI tools, shell configuration,
dotfiles, and user launch agents. They should not take ownership of MDM software or invasive vendor
installers.

## Homebrew

### Configuration

- Prefix: `/opt/homebrew`
- Architecture: Apple Silicon only
- Taps:
  - `deskflow/tap`
  - `homebrew/services`
  - `jesseduffield/lazydocker`
- Running Homebrew services: none
- A stale user LaunchAgent exists for `homebrew.mxcl.colima.plist`, but `colima` is not installed.

Some casks update themselves. Consequently, Homebrew's recorded cask version is older than the app
bundle version for apps such as AltTab, Brave, Cursor, DBeaver, Discord, JetBrains Toolbox,
GitButler, Msty, OrbStack, Raycast, and Visual Studio Code.

### Formulae

The following leaves are the intentionally installed formulae. Their dependencies should not be
declared individually:

| Formula | Current version | Recommended future owner |
| --- | --- | --- |
| `awscli` | 2.34.63 | Nix/Home Manager (`pkgs.awscli2`) |
| `btop` | 1.4.7 | Home Manager |
| `cffi` | 2.0.0_1 | Remove; orphan Homebrew leaf with no installed dependents |
| `docker` | 29.5.3 | Remove Homebrew formula; OrbStack already provides the active Docker CLI/runtime |
| `docker-compose` | 5.1.4 | Remove Homebrew formula; OrbStack already provides the active Compose shim |
| `doppler` | 3.76.0 | Home Manager; already in `hm.work` |
| `fnm` | 1.39.0 | Home Manager; already in `hm.coding` |
| `git` | 2.54.0 | Home Manager; already in `hm.coding` |
| `hub` | 2.14.2 | Remove after confirming no remaining use; prefer `gh` |
| `hurl` | 8.0.1 | Remove; not needed on this machine |
| `isl` | 0.27 | Remove; orphan Homebrew leaf with no installed dependents |
| `jesseduffield/lazydocker/lazydocker` | 0.25.2 | Home Manager if Darwin package is available; otherwise Homebrew |
| `jq` | 1.8.1 | Home Manager |
| `libpq` | 18.4 | Home Manager or Homebrew, depending on work-project compatibility |
| `mcfly` | 0.9.4 | Home Manager |
| `fastfetch` | 2.63.1 | Home Manager; replacement for the removed `neofetch` package |
| `starship` | 1.25.1 | Home Manager |
| `thefuck` | 3.32 | Home Manager |
| `watch` | 4.0.6 | Home Manager |
| `zoxide` | 0.9.9 | Home Manager |
| `zsh-autosuggestions` | 0.7.1 | Home Manager |
| `zsh-syntax-highlighting` | 0.8.0 | Home Manager |

Homebrew also contains normal dependencies such as Python, OpenSSL, SQLite, `gettext`, `krb5`,
`readline`, and compression libraries. They should disappear naturally when their formula
dependents move to Nix or are removed.

### Casks

These are already installed through Homebrew and should initially remain casks, declared through
nix-darwin:

| Cask | Cask | Cask |
| --- | --- | --- |
| `alt-tab` | `audiorelay` | `blackhole-16ch` |
| `blackhole-2ch` | `brave-browser` | `bruno` |
| `cleanshot` | `codex` | `cursor` |
| `dbeaver-community` | `deskflow/tap/deskflow` | `discord` |
| `font-caskaydia-mono-nerd-font` | `ghostty` | `gitbutler` |
| `insomnia` | `jetbrains-toolbox` | `kitty` |
| `moonlight` | `msty` | `obs` |
| `orbstack` | `proton-mail` | `raycast` |
| `rectangle` | `session-manager-plugin` | `tabby` |
| `teamviewer` | `visual-studio-code` |  |

`session-manager-plugin` is recorded both as a Homebrew cask and an installer receipt. Keep only
one declarative owner.

## Applications Outside Homebrew

### Mac App Store

These can be declared with nix-darwin `homebrew.masApps`. Mac App Store authentication remains an
external prerequisite, and removing an entry does not uninstall the app.

| App | App Store ID | Recommendation |
| --- | ---: | --- |
| Bitwarden | 1352778147 | Keep MAS or move to cask; do not also install `pkgs.bitwarden-desktop` |
| GarageBand | 682658836 | MAS |
| GIPHY CAPTURE | 668208984 | MAS if still wanted |
| iMovie | 408981434 | MAS |
| Keynote | 409183694 | MAS |
| Numbers | 409203825 | MAS |
| Pages | 409201541 | MAS |
| Tailscale | 1475387142 | Keep MAS because its network extension integrates with macOS |

### Vendor or Manual Applications

| Application | Current source signal | Recommended future owner |
| --- | --- | --- |
| Arc | Identified developer | Homebrew cask `arc` |
| Google Chrome | Google updater/vendor install | Homebrew cask `google-chrome`, if still required |
| Google Drive, Docs, Sheets, Slides | Google Drive installer and generated shortcuts | Keep vendor/manual; it installs privileged integration |
| HTTPie Desktop | Identified developer | Manual; no exact Homebrew cask found |
| Scroll Reverser | Identified developer | Homebrew cask `scroll-reverser` |
| Slack | Identified developer | Homebrew cask `slack` |
| T3 Code (Nightly) | Identified developer | Nix package `t3code` (nightly GitHub prerelease) |
| Zwift | Vendor package receipt | Homebrew cask `zwift` |

Brave-installed web apps exist under `~/Applications/Brave Browser Apps.localized`: Gather,
GitHub, Linear, NextChat, Notion, Slack, and Spotify. These are browser profile state, not packages
to manage with Nix.

DataGrip and WebStorm are installed under `~/Applications` by JetBrains Toolbox. Keep Toolbox as
the owner or replace individual IDEs deliberately; do not let both Toolbox and Nix/Homebrew own the
same IDE.

### Organization-Managed Software

The Mac is enrolled in user-approved MDM and has organization-managed privileged components:

- CrowdStrike Falcon
- SentinelOne
- Fleet/Orbit
- Bootstrap Buddy
- Escrow Buddy

These include LaunchDaemons, LaunchAgents, endpoint-security extensions, and a SentinelOne network
extension. They are outside this repository's ownership boundary. Never remove, replace, or
declaratively clean them up from nix-darwin or Homebrew.

TeamViewer and Google updater also install privileged helpers. Their cask/vendor lifecycle needs to
be tested before enabling destructive Homebrew cleanup.

### Background and Privileged Components

Observed user LaunchAgents:

- `com.jetbrains.toolbox.plist`
- `com.lwouis.alt-tab-macos.plist`
- `homebrew.mxcl.colima.plist` (stale; Colima is absent)

Observed non-Apple system LaunchAgents:

- CrowdStrike Falcon user agent
- Google Keystone agent and XPC service
- SentinelOne agent and helper

Observed non-Apple system LaunchDaemons:

- Fleet/Orbit
- Google updater/Keystone
- OrbStack privileged helper
- SentinelOne services
- Session Manager Plugin
- TeamViewer helpers and uninstall watcher

Observed third-party system extensions:

- OBS virtual camera extension
- CrowdStrike Falcon endpoint-security extension
- SentinelOne network-monitoring extension

These components explain why a conservative Homebrew cleanup policy is required. Several
applications are more than an `.app` bundle and need approval, a reboot, or a vendor uninstaller
for a complete lifecycle.

## Development Environment

### Shell and PATH

The login shell is `/bin/zsh`. Current shell startup files are imperative:

- `~/.zprofile`
  - initializes Homebrew
  - adds JetBrains Toolbox scripts
  - sources OrbStack shell integration
- `~/.zshrc`
  - initializes Starship, `fnm`, McFly, `hub`, and Zoxide
  - sources Homebrew Zsh autosuggestions and syntax highlighting
  - adds `libpq` and Bun to `PATH`
  - defines work-specific `pnpm` and Doppler aliases

The repository currently configures Bash, not Zsh. A shared shell module should reproduce the
portable behavior through Home Manager while preserving OrbStack and Toolbox integration on Darwin.

### Language and Package Managers

- `fnm` manages Node.js versions: 20.8.1, 20.12.0, 22.9.0, 22.11.0, 22.12.0, 24.3.0, and
  24.11.1; default is 24.3.0.
- Global npm packages: only npm and Corepack.
- Global Bun packages: `@types/bun` and TypeScript.
- Bun is installed imperatively under `~/.bun`, version 1.1.45.
- pnpm 9.15.0 and Yarn 1.22.22 come from the active Node installation.
- No `pipx`, `uv` tools, Rustup, Cargo installs, `asdf`, `mise`, or MacPorts were found.
- Git is configured in `~/.gitconfig`; the repository's Home Manager Git configuration already
  covers most of it.

### Containers

- OrbStack is installed and is the active Docker context.
- Docker CLI and Docker Compose come from Homebrew.
- A stale Colima Docker context and LaunchAgent remain, but Colima is not installed or running.
- OrbStack's shell integration and privileged helper must remain vendor-managed.

### Editors

- Visual Studio Code and Cursor are Homebrew casks.
- Both have extensive, partially overlapping extension sets.
- User settings, keybindings, MCP settings, and snippets live below:
  - `~/Library/Application Support/Code/User`
  - `~/Library/Application Support/Cursor/User`
- The eventual migration should manage human-authored JSON/settings and extension lists, but not
  editor databases under `globalStorage`.

### User Configuration Worth Migrating

- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.stCommitMsg`
- `~/.zprofile`
- `~/.zshrc`
- `~/.nuxtrc`
- `~/.config/btop`
- `~/.config/kitty`
- selected VS Code and Cursor settings/keybindings/snippets
- selected Raycast configuration only if an exportable, stable format is available

Do not import private SSH keys, known-host databases, editor state databases, browser profiles, or
application caches into this repository.

## Current macOS Preferences

Observed preferences that are good initial nix-darwin candidates:

- Dark appearance
- Locale `en_US` with France region
- French-PC keyboard layout
- Dock auto-hide enabled, size 64
- Bottom-right hot corner set to Quick Note
- Finder shows hidden files
- Finder uses list view
- Finder shows the path bar
- Trackpad right click and standard gestures enabled; tap-to-click disabled

Only explicitly chosen preferences should be added. Do not dump entire `defaults` domains into Nix:
many values are generated state, hardware-specific, or managed by macOS/MDM.

## Repository Compatibility Audit

### Required composition changes

- Add `aarch64-darwin` to `config.systems`.
- Add the nix-darwin flake input and its flake-parts flake module.
- Add a Darwin module namespace and a `darwinConfigurations` host.
- Derive home directories per host/platform; `/home/${username}` is invalid on macOS.
- Integrate Home Manager using `inputs.home-manager-darwin.darwinModules.home-manager`.

### Home Manager modules

| Module | Darwin status | Required action |
| --- | --- | --- |
| `comma` | Portable | Reuse |
| `work` | Mostly portable | Verify packages on `aarch64-darwin`; move shell function into shared shell config |
| `coding` | Mixed | Split portable CLI/Git/Jujutsu from Linux-only Cursor wrapper, desktop file, NVIDIA command, Linux `jj-ryu`, and `systemd` service |
| `bitwarden` | Mixed | Do not install Linux-oriented desktop package on Darwin; derive `SSH_AUTH_SOCK` from home directory |
| `browser` | Linux-oriented | Use a cask on Darwin; XDG default-app settings do not configure macOS LaunchServices |
| `cursor-pointer` | Linux desktop | Do not compose on Darwin |
| `discord` | Needs verification | Prefer cask initially; Nixcord behavior on Darwin must be tested separately |
| `spotify` | Needs verification | Prefer cask or Brave web app initially |
| `onlyoffice` | Needs verification | Prefer cask if required |
| `plasma`, `niri`, `noctalia`, `vicinae` | Linux desktop | Do not compose on Darwin |
| `curseforge` | Linux AppImage | Do not compose on Darwin |
| `kde-connect`, `logitech` | Linux-specific packages | Do not compose on Darwin |

All `flake.modules.nixos.*` modules remain NixOS-only and should not be altered merely to make the
Darwin host evaluate.

### Known hardcoded Linux paths

- `hosts/pc-fixe/default.nix`: `/home/${username}`
- `modules/bitwarden.nix`: `/home/${username}/.bitwarden-ssh-agent.sock`
- `modules/secrets.nix`: `/home/${username}/...`
- `modules/noctalia/noctalia.nix`: `/home/${config.home.username}/...`

Portable modules should use `config.home.homeDirectory`. NixOS-only modules may keep Linux paths
when that is clearer, but should still avoid hardcoding the username.

## Inventory Commands

The main read-only commands used for this snapshot were:

```bash
sw_vers
system_profiler SPHardwareDataType SPSoftwareDataType
system_profiler SPApplicationsDataType -json
brew config
brew tap
brew leaves
brew list --formula --versions
brew list --cask --versions
brew services list
pkgutil --pkgs
systemextensionsctl list
profiles status -type enrollment
defaults read -g
defaults read com.apple.dock
defaults read com.apple.finder
defaults read com.apple.AppleMultitouchTrackpad
```
