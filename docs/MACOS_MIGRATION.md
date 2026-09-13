# macOS Application Migration

This is the current handoff and operating plan for completing application ownership on
`macbook-pro`. Run the next inventory from the Mac. Do not infer its installed state from an old
snapshot or from the Nix configuration.

## Current Repository State

The repository currently provides:

- `darwinConfigurations.macbook-pro` for `aarch64-darwin`
- nix-darwin with integrated Home Manager
- the same shared Zsh, coding, command-line, and agent configuration as Linux
- Darwin-only OrbStack and JetBrains Toolbox paths in the shared shell module
- selected dark appearance, Dock, and Finder defaults
- Home Manager applications including Brave, Cursor, VS Code, Discord, DataGrip, LocalSend, and
  T3 Code
- declarative Homebrew casks for Codex, Deskflow, and RustDesk

The duplicated Darwin development module was deleted. The old broad Homebrew/MAS module remains
inactive as a migration checklist; do not compose it directly because it overlaps with applications
already owned by Home Manager.

The live Mac may still contain applications installed by Homebrew, the Mac App Store, vendor
installers, or the organization. That is expected until the inventory below is complete.

## Live Inventory Snapshot (2026-09-13)

Captured on `macbook-pro` after the module refactor landed. Home Manager already owned the whole
portable CLI stack, so no formula reconciliation was left to do.

- Homebrew casks installed: 28 before this pass, 14 now. `obs` and `teamviewer` are the only
  undeclared casks left; both need `sudo` to remove.
- Homebrew formulae installed: 0. `brew leaves` and `brew list --formula` are both empty.
- Homebrew taps: only `deskflow/tap`. `lizardbyte/homebrew` and `homebrew/services` were unused
  and untapped.
- Home Manager applications: Brave, Cursor, DataGrip, Discord, LocalSend, T3 Code, Visual Studio Code.
- Mac App Store applications: Bitwarden, GarageBand, GIPHY CAPTURE, iMovie, Keynote, Numbers, Pages,
  Tailscale.
- Unmanaged drag-and-drop installs: none. ChatGPT, Scroll Reverser, and Slack moved to Home Manager;
  Arc and HTTPie were moved to the Trash; Google Chrome and Zwift are pending a `sudo` removal.
- External owners that activation must never touch: CrowdStrike Falcon
  (`com.crowdstrike.falcon.Agent` endpoint-security extension), SentinelOne
  (`com.sentinelone.network-monitoring` network extension), and Google Drive. The machine is
  MDM-enrolled through `welii.mdm.getprimo.com`.
- `mas` does not need to be installed as a formula: nix-darwin injects `pkgs.mas` into the
  `brew bundle` PATH.

## Ownership Rules

Assign exactly one owner to every retained application:

| Owner | Use for |
| --- | --- |
| Home Manager | Portable CLI tools, editors supported by nixpkgs, shell configuration, dotfiles, and user services |
| Declarative Homebrew | Native macOS GUI applications, self-updating apps, audio drivers, privileged helpers, and system extensions |
| Mac App Store | Applications whose MAS distribution or system integration is preferable |
| External | MDM software, organization-required tools, Google Drive integration, and vendor-managed software that should not be touched by activation |

Never install the same application through both Home Manager and Homebrew. Keep browser profiles,
editor databases, credentials, SSH keys, application caches, and generated web apps outside Nix.

Do not remove or manage organization security software such as CrowdStrike, SentinelOne, Fleet, or
other MDM components.

## Live Inventory Procedure

Run from a clean checkout on the Mac. Store raw command output outside the repository; only reviewed
decisions belong here.

### 1. Capture installed state

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

mas list
pkgutil --pkgs
systemextensionsctl list
profiles status -type enrollment
```

Also inspect:

- `/Applications`
- `~/Applications`
- `~/Applications/Home Manager Apps`
- active login items and LaunchAgents
- applications installed through JetBrains Toolbox
- the active OrbStack Docker context

### 2. Inspect declarative owners

```bash
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.brews --json
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.casks --json
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.masApps --json
nix eval .#darwinConfigurations.macbook-pro.config.home-manager.users.vincent.home.packages \
  --apply 'builtins.map (package: package.name or "")' --json
```

Inspect the generated Brewfile before any activation:

```bash
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.brewfile --raw
```

### 3. Record decisions

Keep this table limited to intentionally installed leaves and applications. Re-run the capture
commands before trusting it.

| Application | Installed owner | Decision | Future owner | Action or caveat | Verified |
| --- | --- | --- | --- | --- | --- |
| Visual Studio Code | Home Manager + Homebrew cask | remove cask | home-manager | Cask removed 2026-09-13. `code` now resolves to `/etc/profiles/per-user/vincent/bin/code` (1.133.0). | yes |
| Cursor | Home Manager + stale Homebrew cask | remove cask | home-manager | Cask was pinned to 1.2.1 with no app on disk. Removed 2026-09-13. | yes |
| Codex | Homebrew cask | keep | homebrew | Not a duplicate: the `hm.agentCodex` wrapper execs `/opt/homebrew/bin/codex`. The deprecated `codex-app` cask was removed 2026-09-13. | yes |
| Deskflow | Homebrew cask | keep | homebrew | Declared in `darwin.deskflow` through `deskflow/tap`. | yes |
| RustDesk | Homebrew cask | keep | homebrew | Declared in `darwin.rustdesk`. | yes |
| AltTab, AudioRelay, CleanShot, JetBrains Toolbox, Moonlight, OrbStack, Raycast, Rectangle | Homebrew cask | keep | homebrew | Declared in `darwin.homebrew`. Native GUI, self-updating, or privileged-helper applications. | no |
| Bruno, DBeaver, GitButler, Insomnia, Msty, Proton Mail, Tabby | Homebrew cask | remove | none | Casks removed 2026-09-13. | yes |
| OBS, TeamViewer | Homebrew cask | remove | none | Cask removal needs `sudo` (OBS ships a camera system extension). | no |
| Ghostty | Homebrew cask | keep | home-manager + homebrew | `hm.ghostty` now writes the shared config on both hosts and installs the package on Linux; the cask owns the macOS app because nixpkgs marks ghostty unsupported on Darwin. | no |
| kitty | Homebrew cask | remove | none | Cask removed 2026-09-13 in favour of Ghostty. | yes |
| BlackHole 2ch, BlackHole 16ch | Homebrew cask | remove | none | Drivers in `/Library/Audio/Plug-Ins/HAL`. No installed cask depends on them. Removal needs `sudo`. | no |
| Font Caskaydia Mono Nerd Font | Homebrew cask | move | nix-darwin + nixos | Cask removed 2026-09-13. `modules/fonts.nix` installs `nerd-fonts.caskaydia-mono` system-wide on both hosts (Nix 3.5.0 vs cask 3.4.0). | no |
| Slack | unmanaged | migrate | home-manager | Installed 4.42.117, nixpkgs 4.51.180. Declared in `hm.guiApps`; delete `/Applications/Slack.app` after the Home Manager copy lands. | no |
| ChatGPT | unmanaged | migrate | home-manager | Bundle id `com.openai.codex`. Installed 26.908.40834, nixpkgs 26.803.81509 from the same `codex-app-prod` source. Declared in `hm.guiApps`. | no |
| Scroll Reverser | unmanaged | migrate | home-manager | Installed 1.8.2, nixpkgs 1.9. Declared in `hm.guiApps`. | no |
| Arc | unmanaged | remove | none | Moved to Trash 2026-09-13. The nixpkgs `arc-browser` attribute was dropped upstream as unmaintained. | yes |
| HTTPie | unmanaged | remove | none | Moved to Trash 2026-09-13. Available as `pkgs.xh` or `pkgs.httpie` if it is ever needed again. | yes |
| Google Chrome, Zwift | unmanaged | remove | none | Root-owned bundles; removal needs `sudo`. | no |
| Google Docs, Google Sheets, Google Slides | external | keep | external | Not applications: these are `com.google.drivefs.shortcuts.*` shortcuts generated by Google Drive. Never manage them from Nix. | yes |
| Bitwarden, GarageBand, GIPHY CAPTURE, iMovie, Keynote, Numbers, Pages, Tailscale | Mac App Store | keep | mas | Declare through `homebrew.masApps` in Phase 4. | no |
| CrowdStrike Falcon, SentinelOne, Google Drive | external | keep | external | Organization security and vendor integrations. Never manage them from Nix. | yes |

For every item:

1. Decide `keep` or `remove`.
2. If kept, select exactly one future owner.
3. Check for privileged helpers, drivers, system extensions, or organization policy.
4. Add or change one small ownership group at a time.
5. Build and inspect before activation.
6. Mark the row verified only after the application launches and its integration works.

## Portable Formulae

Every portable tool that used to come from Homebrew is now supplied by Home Manager, so no formula
reconciliation remains. Re-run `brew leaves` and `brew list --formula` before each phase rather
than trusting this snapshot.

## Migration Order

Phase 1 - remove duplicate ownership (done 2026-09-13)

1. Dropped the `visual-studio-code` and `cursor` casks in favour of the Home Manager copies, and
   dropped the deprecated `codex-app` cask.
2. Confirmed `codex` stays on Homebrew because the `hm.agentCodex` wrapper execs
   `/opt/homebrew/bin/codex`.

Phase 2 - declare the retained casks (done 2026-09-13)

1. Ghostty is declared: `modules/ghostty.nix` shares one config across both hosts and adds the
   `ghostty` cask on Darwin only.
2. Slack, ChatGPT, and Scroll Reverser moved from manual installs to `modules/gui-apps.nix`.
3. The Caskaydia Mono Nerd Font moved from a cask to `fonts.packages` in `modules/fonts.nix`,
   which installs it on both hosts.
4. The retained graphical casks are declared in `darwin.homebrew`, which now lists casks only.

Phase 3 - unmanaged applications (done 2026-09-13)

1. Arc and HTTPie moved to the Trash, the Brave Slack web-app shortcut was deleted, and Google
   Chrome and Zwift are pending a `sudo` removal.
2. Google Docs/Sheets/Slides are `com.google.drivefs.shortcuts.*` Drive placeholders rather than
   applications, so they stay untouched.

Phase 4 - Mac App Store (open)

1. The eight retained App Store applications are still owned by the App Store rather than by
   `homebrew.masApps`. `brew bundle cleanup` ignores them, so leaving them undeclared does not
   block activation; declaring them is optional tidiness that needs a confirmed App Store session.

Phase 5 - tighten cleanup (done 2026-09-13)

1. `homebrew.onActivation.cleanup` is `"check"`, which runs `brew bundle cleanup` and aborts
   activation on the first undeclared package. Phase 2 declared every retained cask before the flip.
2. Keep invasive vendor and organization integrations external.
3. Consider `"uninstall"` only after repeated successful checks. Never use `"zap"` on this
   work-managed machine.

Do not combine application migration with changing the Nix installer. The current configuration
preserves the official multi-user Nix installation. Treat a Nix/Lix/Determinate migration as a
separate change with its own rollback plan.

## Application Preferences

Three applications keep their settings in the standard per-user defaults domain, so
`modules/darwin/macos-defaults.nix` declares them through `system.defaults.CustomUserPreferences`:
Rectangle (`com.knollsoft.Rectangle`), AltTab (`com.lwouis.alt-tab-macos`), and Scroll Reverser
(`com.pilotmoon.scroll-reverser`). The declared values reproduce the pre-migration plist exactly, so
the first activation is value-preserving rather than a reset.

This is a seed, not an enforcement loop. nix-darwin runs `defaults write` as the primary user during
activation, and a running application holds its own in-memory copy, so:

- Quit the application before switching, otherwise it flushes its settings over the declared values
  when it exits.
- A change made in the application's own UI wins until the next activation.
- Only intended keys are declared. Sparkle update state (`SU*`, `lastVersion`), window frames, and
  AltTab's `preferencesVersion` migration marker stay with the applications.

Raycast is deliberately excluded. Its `com.raycast.macos` domain is 68 KB of internal bookkeeping
keyed by extension UUIDs, and the real configuration lives in a 518 MB SQLite store under
`~/Library/Application Support/com.raycast.macos`. It also syncs through Raycast's own cloud account.
None of that is stable enough to declare, so Raycast keeps ownership of its own settings.

### Verification

```bash
nix eval .#darwinConfigurations.macbook-pro.config.system.defaults.CustomUserPreferences --json
defaults read com.knollsoft.Rectangle
defaults read com.lwouis.alt-tab-macos
defaults read com.pilotmoon.scroll-reverser
```

## Validation

Before activation:

```bash
nix fmt -- --ci
nix flake check
nix eval .#darwinConfigurations.macbook-pro.system --raw
nix build .#darwinConfigurations.macbook-pro.system
nix eval .#darwinConfigurations.macbook-pro.config.homebrew.brewfile --raw
```

Apply conservatively on the Mac:

```bash
darwin-rebuild build --flake .#macbook-pro
sudo darwin-rebuild switch --flake .#macbook-pro
```

After activation:

```bash
darwin-rebuild --list-generations
home-manager generations
brew bundle check
brew services list
launchctl print gui/$(id -u)
```

Verify the Mac App Store session, OrbStack Docker context, Google Drive, organization agents, system
extensions, shell startup, editor configuration, Spotlight application discovery, and work-project
commands.
