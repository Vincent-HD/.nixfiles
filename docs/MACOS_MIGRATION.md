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

- Homebrew casks installed: 28 before this pass, 25 after the Phase 1 removals.
- Homebrew formulae installed: 0. `brew leaves` and `brew list --formula` are both empty.
- Home Manager applications: Brave, Cursor, DataGrip, Discord, LocalSend, T3 Code, Visual Studio Code.
- Mac App Store applications: Bitwarden, GarageBand, GIPHY CAPTURE, iMovie, Keynote, Numbers, Pages,
  Tailscale.
- Unmanaged drag-and-drop installs: Arc, ChatGPT, Google Chrome, Google Docs, Google Sheets, Google
  Slides, HTTPie, Scroll Reverser, Slack, Zwift.
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
| AltTab, AudioRelay, Bruno, CleanShot, DBeaver, GitButler, Insomnia, JetBrains Toolbox, Moonlight, Msty, OBS, OrbStack, Proton Mail, Raycast, Rectangle, Tabby, TeamViewer | Homebrew cask | keep | homebrew | Undeclared until Phase 2. Native GUI, self-updating, or privileged-helper applications. | no |
| Ghostty, kitty | Homebrew cask | undecided | homebrew | Overlapping terminal emulators; pick one before declaring. | no |
| BlackHole 2ch, BlackHole 16ch | Homebrew cask | undecided | homebrew | Audio drivers, not applications; confirm whether both channels are used. | no |
| Font Caskaydia Mono Nerd Font | Homebrew cask | move | nix-darwin | Belongs in `fonts.packages`, not in the Brewfile. | no |
| Arc, ChatGPT, Google Chrome, Google Docs, Google Sheets, Google Slides, HTTPie, Scroll Reverser, Slack, Zwift | unmanaged | undecided | homebrew/remove/external | Drag-and-drop installs with no package manager owner. | no |
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

Phase 2 - declare the retained casks

1. Move the retained cask list into one composed Darwin Homebrew feature module.
2. Move the Caskaydia Mono Nerd Font to `fonts.packages` instead of a cask.
3. Resolve the Ghostty/kitty overlap and the BlackHole driver question.

Phase 3 - unmanaged applications

1. Classify Arc, ChatGPT, Google Chrome, Google Docs/Sheets/Slides, HTTPie, Scroll Reverser, Slack,
   and Zwift as cask, removed, or external.

Phase 4 - Mac App Store

1. Declare the eight retained App Store applications through `homebrew.masApps` once the App Store
   session is confirmed.

Phase 5 - tighten cleanup

1. Flip `homebrew.onActivation.cleanup` from `"none"` to `"check"`. `"check"` runs
   `brew bundle cleanup` and aborts activation on the first undeclared package, so it can only be
   enabled after Phases 2-4 declare every retained item.
2. Keep invasive vendor and organization integrations external.
3. Consider `"uninstall"` only after repeated successful checks. Never use `"zap"` on this
   work-managed machine.

Do not combine application migration with changing the Nix installer. The current configuration
preserves the official multi-user Nix installation. Treat a Nix/Lix/Determinate migration as a
separate change with its own rollback plan.

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
