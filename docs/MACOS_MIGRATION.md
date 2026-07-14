# macOS Migration Ledger

The Mac migration is intentionally incremental. Each activation may adopt one application or one
small ownership boundary only. Do not add the full Homebrew inventory or the complete Linux Home
Manager composition to `hosts/macbook-pro/default.nix`.

## Rules

1. Prefer an existing repository module when it supports Darwin.
2. Make the existing module cross-platform instead of creating a duplicate Darwin-only module.
3. Add exactly one module to the Mac host composition.
4. Evaluate and build the complete Darwin system before switching.
5. Switch, test the migrated application, and keep its existing installation during testing.
6. Remove the previous manual or Homebrew installation only after the Nix-managed application has
   passed its test checklist.
7. Record the result here before selecting the next application.

Homebrew cleanup remains disabled. `darwin.homebrew`, `darwin.macosDefaults`,
`hm.darwinDevelopment`, and `nix-homebrew` are deliberately not composed into the active Mac host.

## Activation 0: Darwin Baseline and Brave

Status: complete

Ownership introduced:

- nix-darwin owns the `macbook-pro` system generation and Nix daemon configuration.
- nix-darwin adopts the system Bash/Zsh startup files created by the official Nix installer.
- Home Manager owns the `vincent` generation.
- The existing `hm.browser` module provides Brave from nixpkgs.

Ownership that remained unchanged during testing:

- `/opt/homebrew` and every Homebrew formula/cask
- existing `/Applications/Brave Browser.app`
- `~/.zprofile`, `~/.zshrc`, and `~/.gitconfig`
- the current macOS hostname
- macOS Finder and Dock defaults
- automatic Nix-store optimization
- the installed Nix implementation; the host uses `pkgs.nix`, not Lix

Build without activating:

```bash
nix --extra-experimental-features "nix-command flakes" \
  build .#darwinConfigurations.macbook-pro.system --dry-run

nix --extra-experimental-features "nix-command flakes" \
  build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system
```

Run nix-darwin's root-only, non-activating compatibility check:

```bash
sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro
```

First activation:

```bash
sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  switch --flake .#macbook-pro
```

Test before removing Homebrew Brave:

- `darwin-rebuild --list-generations` shows the first generation.
- `nix --version` still reports Nix 2.34.x.
- a new Bash and Zsh shell can find both Nix and Homebrew commands.
- existing `~/.zprofile` and `~/.zshrc` behavior still works.
- `brew list --cask brave-browser` still succeeds.
- `~/Applications/Home Manager Apps/Brave Browser.app` exists and launches.
- quit every running Brave process, then launch the Nix-managed copy by its exact path:

  ```bash
  open "$HOME/Applications/Home Manager Apps/Brave Browser.app"
  ```

- The Nix-managed Brave can open an existing profile, browse, download a file, play audio/video,
  and use required extensions.
- A reboot preserves Nix, Home Manager, Homebrew, and both Brave installations.

Only after those checks pass, remove the old Homebrew ownership:

```bash
brew uninstall --cask brave-browser
```

Then re-test the Nix-managed Brave before marking this activation complete.

Result:

- The Homebrew Brave cask and `/Applications/Brave Browser.app` were removed.
- The Home Manager Brave bundle launches and runs from
  `~/Applications/Home Manager Apps/Brave Browser.app`.
- A stale old-version process and LaunchServices registration initially caused an empty window.
  Fully quitting the old process resolved it without rebooting macOS.

## Activation 1: Discord

Status: complete

The existing repository `hm.discord` module takes priority over the plain Homebrew Discord cask. It
provides Discord through Nixcord with Equicord and the repository's configured plugins.

Keep `/Applications/Discord.app` and the Homebrew `discord` cask installed during testing.

Version note:

- current Homebrew Discord: `0.0.393`
- repository/Nixcord Discord: `0.0.392`
- repository Equicord: `1.14.13.1`

This temporarily moves Discord back one release. Do not remove the Homebrew copy unless the
repository-managed copy works correctly.

Build and run the root-only check:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro
```

Activate:

```bash
mkdir -p "$HOME/.local/state/nixfiles-migration-backups"
cp "$HOME/Library/Application Support/Equicord/settings/settings.json" \
  "$HOME/.local/state/nixfiles-migration-backups/equicord-settings-before-activation-1.json"

osascript -e 'quit app "Discord"'

sudo darwin-rebuild switch --flake .#macbook-pro
```

Activation replaces the existing Equicord settings with the repository's configured plugin set.
The backup is only for rollback or comparison; the repository configuration takes priority.

Test before removing Homebrew Discord:

- fully quit every existing Discord process
- launch the Nix-managed copy by its exact path:

  ```bash
  open "$HOME/Applications/Home Manager Apps/Discord.app"
  ```

- sign in and verify existing servers, direct messages, notifications, microphone, speakers,
  screen sharing, and streaming
- verify Equicord loads and the configured plugins work
- confirm the running process originates under `~/Applications/Home Manager Apps/Discord.app`
- restart Discord and verify it still launches correctly

Only after those checks pass:

```bash
brew uninstall --cask discord
```

Fully quit Discord again, launch the Home Manager copy, and repeat the critical checks.

Result:

- The Homebrew Discord cask and `/Applications/Discord.app` were removed.
- The Home Manager Discord bundle remains at `~/Applications/Home Manager Apps/Discord.app`.
- The repository-managed Equicord configuration works.

## Queue

Choose the next item only after Activation 0 is complete.

| Candidate | Existing repository module | Current owner | Notes |
| --- | --- | --- | --- |
| Bitwarden | `hm.bitwarden` | Mac App Store | Blocked: nixpkgs package currently requires insecure EOL Electron 39.8.10 |
| Discord | `hm.discord` | Home Manager | Activation 1 complete |
| Git/developer tools | `hm.coding` | Homebrew/manual | Refactor Linux-only parts before composing; migrate tools individually |
| Spotify | `hm.spotify` | Not currently installed | Do not install until requested |
| Brave | `hm.browser` | Home Manager | Activation 0 complete |

## Activation 2: Starship

Status: complete

Starship is split into the reusable `hm.starship` feature module and added as the only new ownership
boundary. Both Homebrew and nixpkgs currently provide version `1.25.1`.

The module manages the Starship binary but deliberately does not manage Bash/Zsh integration.
Existing `~/.zshrc` continues to run `eval "$(starship init zsh)"`.

Keep the Homebrew formula during testing:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed binary directly before removing Homebrew:

```bash
/etc/profiles/per-user/vincent/bin/starship --version
/etc/profiles/per-user/vincent/bin/starship explain
zsh -lic 'starship --version; command -v starship'
```

Open a new terminal and verify the prompt renders correctly, Git repository prompt information
works, and no shell startup errors appear.

Only after those checks pass:

```bash
brew uninstall starship
zsh -lic 'starship --version; command -v starship'
```

The final command must resolve to `/etc/profiles/per-user/vincent/bin/starship`.

Result:

- Homebrew Starship was removed.
- New interactive Zsh shells resolve Starship from `/etc/profiles/per-user/vincent/bin/starship`.
- The existing user-managed shell initialization continues to render the prompt correctly.

## Activation 3: Zoxide

Status: complete

Zoxide is split into the reusable `hm.zoxide` feature module and added as the only new ownership
boundary. Both Homebrew and nixpkgs currently provide version `0.9.9`.

The module manages the Zoxide binary but deliberately does not manage Bash/Zsh integration.
Existing `~/.zshrc` continues to run `eval "$(zoxide init zsh)"`.

Keep the Homebrew formula during testing:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed binary directly before removing Homebrew:

```bash
/etc/profiles/per-user/vincent/bin/zoxide --version
/etc/profiles/per-user/vincent/bin/zoxide query "$HOME"
zsh -lic 'zoxide --version; command -v zoxide; whence -w z'
```

Open a new terminal, visit several directories with `cd`, and verify `z <query>` changes to a
previously visited matching directory.

Only after those checks pass:

```bash
brew uninstall zoxide
zsh -lic 'zoxide --version; command -v zoxide; whence -w z'
```

The final command must resolve Zoxide to `/etc/profiles/per-user/vincent/bin/zoxide`, and `z` must
remain a shell function.

Result:

- Homebrew Zoxide was removed.
- New interactive Zsh shells resolve Zoxide from `/etc/profiles/per-user/vincent/bin/zoxide`.
- The existing user-managed `z` shell function continues to work.

## Activation 4: McFly

Status: complete

McFly is split into the reusable `hm.mcfly` feature module and added as the only new ownership
boundary. Homebrew currently provides version `0.9.4`, while the pinned nixpkgs package provides
version `0.9.3`. This temporarily moves McFly back one patch release.

The module installs only the McFly package. It deliberately does not use Home Manager's
`programs.mcfly` module yet because that would also take ownership of shell integration and McFly
session variables. Existing `~/.zshrc` continues to run `eval "$(mcfly init zsh)"`.

Keep the Homebrew formula during testing:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed binary directly before removing Homebrew:

```bash
/etc/profiles/per-user/vincent/bin/mcfly --version
zsh -lic 'mcfly --version; command -v mcfly; whence -w mcfly-history-widget'
```

Open a new terminal, press `Ctrl-R`, and verify McFly can search and select existing shell history.

Only after those checks pass:

```bash
brew uninstall mcfly
zsh -lic 'mcfly --version; command -v mcfly; whence -w mcfly-history-widget'
```

The final command must resolve McFly to `/etc/profiles/per-user/vincent/bin/mcfly`, and
`mcfly-history-widget` must remain a shell function.

Result:

- Homebrew McFly was removed.
- New interactive Zsh shells resolve McFly from `/etc/profiles/per-user/vincent/bin/mcfly`.
- The existing user-managed `Ctrl-R` history widget continues to work.

## Activation 5: Work Tools

Status: complete

The existing repository `hm.work` module is added to the Mac host as requested. It provides:

- Doppler `3.76.0`
- AWS CLI v2 `2.34.24`
- AWS SSM Session Manager Plugin `1.2.792.0`
- JetBrains DataGrip `2026.1.2`
- a shell-independent `setup_worktree` command

The previous Bash init fragment was converted into a Nix-managed executable, so `setup_worktree`
works from both Bash and Zsh without taking ownership of either shell's startup files. Existing
Doppler authentication and state under `~/.doppler` remain user-managed.

Keep the existing Homebrew AWS CLI, Doppler, and Session Manager Plugin installations during
testing. JetBrains Toolbox also currently owns DataGrip; keep both copies until the Nix-managed
DataGrip has been tested.

Build and activate:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed tools directly before removing existing owners:

```bash
/etc/profiles/per-user/vincent/bin/doppler --version
/etc/profiles/per-user/vincent/bin/aws --version
/etc/profiles/per-user/vincent/bin/session-manager-plugin
open "$HOME/Applications/Home Manager Apps/DataGrip.app"
zsh -lic 'command -v doppler; command -v aws; command -v session-manager-plugin; command -v setup_worktree'
```

From a configured work-project directory, verify an existing `doppler run` command. Verify a
non-destructive AWS command such as `aws sts get-caller-identity`, an SSM session workflow if one is
available, normal DataGrip connection/editor behavior, and `setup_worktree` from Zsh.

Only after every corresponding Nix-managed tool passes its checks:

```bash
brew uninstall doppler
brew uninstall awscli
brew uninstall --cask session-manager-plugin
zsh -lic 'command -v doppler; command -v aws; command -v session-manager-plugin'
```

Do not remove JetBrains Toolbox or its DataGrip installation until all Toolbox-managed IDEs and the
Nix-managed DataGrip copy have been reviewed separately.

Result:

- Homebrew Doppler, AWS CLI, and Session Manager Plugin were removed.
- The Nix-managed work binaries and `setup_worktree` resolve through the per-user profile.
- The Nix-managed DataGrip bundle launches from Home Manager Apps.

## Activation 6: Coding

Status: active; old Homebrew owners retained pending shell migration

The existing `hm.coding` module is adapted for both Linux and Darwin and added to the Mac host.
This is intentionally a broader ownership boundary. It provides:

- Cursor and Visual Studio Code, with `code` resolving to Cursor
- OpenCode, its repository configuration, and a Darwin launch agent for its background service
- Neovim, Vim, uv, GitHub CLI, nil, nixfmt, Fnm, Jujutsu, and JJUI
- cross-platform standalone JJ-Ryu and LightJJ packages
- repository-managed Git and Jujutsu configuration
- a shell-independent `nixswitch` command

Crosspipe remains Linux-only and is installed directly by the Linux host instead of through
`hm.coding`. The NVIDIA-only `check-gpu-video` helper was removed. The Linux-only Cursor desktop
entry, OpenCode systemd service, and MCP NixOS package remain guarded to Linux.

The Mac keeps its existing user-managed Zsh Fnm initialization. Home Manager does not take
ownership of `.zshrc` or `.zprofile`, but activation does take ownership of Git configuration and
the OpenCode configuration file. The Darwin OpenCode configuration omits the NixOS MCP server and
the GitHub MCP entry that depends on the Linux host's managed token file.

Keep Homebrew Cursor, Visual Studio Code, Git, and Fnm installed during testing.

Build and activate:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed tools and applications:

```bash
zsh -lic 'command -v code cursor git fnm opencode nvim uv gh nil nixfmt jj jjui ryu lightjj nixswitch'
open "$HOME/Applications/Home Manager Apps/Cursor.app"
open "$HOME/Applications/Home Manager Apps/Visual Studio Code.app"
git config --list --show-origin
launchctl print "gui/$(id -u)/org.nix-community.home.opencode-web"
```

Verify Cursor and VS Code settings/extensions, Git identity and aliases, Jujutsu repositories,
Fnm automatic Node selection, OpenCode configuration and service, JJUI, JJ-Ryu, and LightJJ.
Remove overlapping Homebrew applications and formulas only after their Nix-managed replacements
pass these checks.

Result:

- The repository-managed coding applications, commands, Git configuration, Jujutsu configuration,
  and OpenCode configuration are active.
- The Darwin OpenCode launch agent is running and its health endpoint reports healthy.
- Homebrew Cursor and Visual Studio Code remain installed pending separate editor checks.
- Hub and Homebrew Fnm were removed during the incremental Zsh migration.
- Homebrew Git was removed after the Nix-managed Git binary and configuration passed their checks.

## Activation 7: Btop

Status: ready to build and activate

The new reusable `hm.btop` module is added to the Mac host as the only new ownership boundary.
Homebrew and nixpkgs both provide btop version `1.4.7`.

The `btop` entry in the inactive `darwin.homebrew` module records the existing Homebrew owner; no
other active Nix or Home Manager configuration in the repository installs btop.

This activation manages only the btop package. It deliberately leaves the existing
`~/.config/btop/btop.conf` untouched because btop updates that file interactively at runtime.
The Darwin build disables btop GPU support because the nixpkgs default GPU-enabled build crashes
with `SIGTRAP` in `Cpu::draw` on this Mac. Linux continues to use the normal GPU-enabled package.

Keep the Homebrew formula installed during testing:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed binary directly:

```bash
/etc/profiles/per-user/vincent/bin/btop --version
/etc/profiles/per-user/vincent/bin/btop
```

Verify CPU, memory, process, disk, network, and battery information render correctly. Change one
temporary option, quit btop, reopen it, and confirm the existing user-managed configuration remains
writable and persists the change.

Only after those checks pass:

```bash
brew uninstall btop
zsh -lic 'command -v btop; btop --version'
```

The final command must resolve btop to `/etc/profiles/per-user/vincent/bin/btop`.

Result:

- The Darwin GPU-disabled Nix btop build runs without producing additional crash reports.
- Homebrew btop was removed.
- New Zsh shells resolve btop from `/etc/profiles/per-user/vincent/bin/btop`.

## Activation 8: RustDesk

Status: ready to build and activate

RustDesk was not previously installed and had no existing repository feature. Nixpkgs exposes a
RustDesk package for Darwin but explicitly marks both Darwin platforms as broken, so this activation
uses a focused nix-darwin module to install the official `rustdesk` Homebrew cask.

The module manages only the RustDesk cask. Homebrew cleanup, automatic updates, and upgrades remain
disabled, so the rest of the existing Homebrew inventory is not adopted or removed.

Build and inspect before activating:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

nix eval .#darwinConfigurations.macbook-pro.config.homebrew.casks --json

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro
```

Activate:

```bash
sudo darwin-rebuild switch --flake .#macbook-pro
```

Test RustDesk:

- Confirm `/Applications/RustDesk.app` exists and launches.
- Grant the required Accessibility, Screen Recording, and Input Monitoring permissions when macOS
  requests them.
- Verify outbound remote control, inbound remote control, keyboard/mouse input, clipboard sharing,
  and multi-display behavior as applicable.
- Quit and reopen RustDesk, then confirm its permissions and settings persist.

RustDesk is already declaratively Homebrew-owned after activation. Do not manually uninstall its
cask while `darwin.rustdesk` remains composed.

## Activation 9: Sunshine

Status: skipped

Sunshine is intentionally Linux-only in this repository. The `sunshine.nix` feature keeps the NixOS
service with CUDA support for the NVIDIA Linux host, and the macOS Home Manager package was removed.

## Activation 10: Deskflow

Status: complete

Deskflow `1.26.0` is currently installed manually through the project's Homebrew tap. Nixpkgs
Deskflow supports Linux only. Upstream recommends Homebrew for macOS because its macOS app is
unsigned and requires Homebrew's quarantine handling.

The existing Deskflow tap and cask declarations are moved from the inactive broad
`darwin.homebrew` inventory into a focused active `darwin.deskflow` feature. Nix-darwin now owns the
desired installation, while Homebrew remains the underlying macOS installer.

The module manages only:

- the `deskflow/tap` Homebrew tap
- the `deskflow/tap/deskflow` cask
- explicit Homebrew trust for `deskflow/tap`, required before Homebrew will load its cask

Homebrew cleanup, automatic updates, and upgrades remain disabled. Existing configuration, server
layout, TLS identity under `~/Library/Deskflow`, and unrelated Homebrew trust entries remain
untouched.

Build and inspect before activating:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

nix eval .#darwinConfigurations.macbook-pro.config.homebrew.taps --json
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.casks --json

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro
```

Activate:

```bash
sudo darwin-rebuild switch --flake .#macbook-pro
```

Test Deskflow:

- Confirm `/Applications/Deskflow.app` still launches.
- Confirm the existing server/client mode, computer layout, TLS identity, and saved settings remain.
- Verify Accessibility permission remains granted. If macOS requests it again, remove the stale
  Deskflow entry from Privacy & Security, then add the current app.
- Test keyboard, mouse, clipboard, reconnect, sleep/wake, and server/client startup behavior.

Deskflow is declaratively Homebrew-owned after activation. Do not manually uninstall the cask while
`darwin.deskflow` remains composed.

Result:

- Nix-darwin owns the upstream Deskflow tap, trust declaration, and cask.
- Existing Deskflow configuration, TLS identity, and application behavior remain functional.

## Activation 11: jq

Status: ready to build and activate

Jq was already present in the repository, but only as an embedded package dependency of the
Linux-only `hm.noctalia-plugins-dependencies` feature. Composing that complete feature on macOS
would incorrectly pull Noctalia and Wayland-specific screen capture tools into the Mac.

Jq is extracted into a reusable `hm.jq` feature and composed on both hosts. The Linux host therefore
retains jq for the Noctalia screen-toolkit plugin, while the Mac gains the same repository-managed
package without duplicating its package declaration.

Homebrew and nixpkgs both provide jq version `1.8.1`. Keep Homebrew jq installed during testing.

Build and activate:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed binary directly:

```bash
/etc/profiles/per-user/vincent/bin/jq --version
printf '{"migration":"works"}\n' | /etc/profiles/per-user/vincent/bin/jq -r .migration
```

Verify any existing scripts or work commands that use jq. Only after those checks pass:

```bash
brew uninstall jq
zsh -lic 'command -v jq; jq --version'
```

The final command must resolve jq to `/etc/profiles/per-user/vincent/bin/jq`.

Result:

- Homebrew jq was removed after the repository-managed binary passed its checks.
- Both hosts now receive jq from the reusable `hm.jq` feature.

## Activation 12: LazyDocker

Status: ready to build and activate

LazyDocker had no active repository owner. Homebrew and nixpkgs both provide version `0.25.2`, and
no installed Homebrew package depends on the current formula.

The new reusable `hm.lazydocker` feature installs only the package on both hosts. It does not manage
LazyDocker configuration or Docker itself. The existing macOS configuration file at
`~/Library/Application Support/lazydocker/config.yml` is empty and remains untouched. LazyDocker
continues to use the current OrbStack Docker context and CLI.

Keep Homebrew LazyDocker and its tap installed during testing.

Build and activate:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Test the Nix-managed binary directly:

```bash
/etc/profiles/per-user/vincent/bin/lazydocker --version
/etc/profiles/per-user/vincent/bin/lazydocker
```

Confirm LazyDocker connects to the OrbStack context, lists containers/images/volumes, displays logs,
and can perform a safe action such as restarting a disposable container. Only after those checks
pass:

```bash
brew uninstall jesseduffield/lazydocker/lazydocker
brew untap jesseduffield/lazydocker
zsh -lic 'command -v lazydocker; lazydocker --version'
```

The final command must resolve LazyDocker to `/etc/profiles/per-user/vincent/bin/lazydocker`.

Result:

- The Nix-managed LazyDocker binary works with the OrbStack Docker context.
- The Homebrew LazyDocker formula and its dedicated tap were removed.
- Both hosts now receive LazyDocker from the reusable `hm.lazydocker` feature.

## Activation 13: Zsh Autosuggestions and Syntax Highlighting

Status: ready to build and activate

The Mac's user-managed `~/.zshrc` currently sources Zsh Autosuggestions and Syntax Highlighting from
Homebrew. Enabling Home Manager's complete `programs.zsh` module would take ownership of the whole
startup file, so this incremental activation migrates only the two package owners.

The new `hm.zshHelpers` feature installs:

- Zsh Autosuggestions `0.7.1`
- Zsh Syntax Highlighting `0.8.0`

The existing `~/.zshrc` remains user-managed and sources a Home Manager-generated
`~/.config/nixfiles/zsh-helpers.zsh` file containing exact Nix store paths.

Build and activate:

```bash
nix build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system

sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro

sudo darwin-rebuild switch --flake .#macbook-pro
```

Open a new terminal and verify:

- typing a previous command displays a suggestion
- pressing the right arrow accepts a suggestion
- valid and invalid commands receive syntax highlighting
- shell startup has no errors

Confirm the integrations loaded:

```bash
zsh -lic 'typeset -f _zsh_autosuggest_start >/dev/null && echo autosuggestions-loaded; print -r -- $ZSH_HIGHLIGHT_VERSION'
```

Only after those checks pass:

```bash
brew uninstall zsh-autosuggestions zsh-syntax-highlighting
```

Result:

- New Zsh shells load both helpers from the Nix per-user profile.
- Homebrew no longer owns either helper.

## Activation 14: Fnm

Status: complete

Fnm was already installed by `hm.coding`, but the Mac's user-managed `~/.zshrc` resolved and
initialized the Homebrew binary because Homebrew appears earlier in `PATH`.

Zsh initialization now calls `/etc/profiles/per-user/vincent/bin/fnm` explicitly. Existing Node
versions, aliases, and the default version remain under `~/Library/Application Support/fnm` and are
not owned or replaced by Nix.

Verification:

```bash
zsh -lic 'command -v fnm; fnm current; fnm default; command -v node; node --version'
```

Result:

- New Zsh shells initialize the Nix-managed Fnm binary.
- Existing Node versions and the `v24.3.0` default remain available.
- Homebrew Fnm was removed.
