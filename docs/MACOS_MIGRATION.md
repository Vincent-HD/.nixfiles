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

The duplicated Darwin development module was deleted, and the one broad Homebrew/MAS module was
reduced to what it now declares: casks in `darwin.homebrew` and the four retained App Store apps.
There is no inactive checklist module left to compose by mistake.

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
- Home Manager applications: Brave, Bitwarden (new this pass), ChatGPT, Cursor, DataGrip, Discord,
  LocalSend, Scroll Reverser, T3 Code, Visual Studio Code.
- Slack and Google Chrome are **not** Home Manager applications. They are pushed by the corporate
  Fleet MDM agent at `/opt/orbit`, which reinstalls both bundles after any removal at a version
  older than the nixpkgs build. They are org-owned and untouchable; see TODO.md for the evidence.
- Mac App Store applications: Keynote, Numbers, Pages, Tailscale. Bitwarden is no longer in this
  group because Home Manager owns it; GarageBand, iMovie, and GIPHY CAPTURE were dropped from the
  declaration as unmanaged.
- Unmanaged drag-and-drop installs: none left. ChatGPT and Scroll Reverser moved to Home Manager;
  Arc, HTTPie, Zwift, WebStorm, and the Proton Mail leftovers were moved to the Trash. Slack and
  Google Chrome were handed back to the org that installs them.
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
| Slack | unmanaged | external | none | MDM-installed by Fleet orbit. Reappears after `sudo rm -rf` at 4.42.117, older than the nixpkgs 4.51.180 build, so it cannot be Nix-managed. Removed from `hm.guiApps`. | no |
| ChatGPT | unmanaged | migrate | home-manager | Bundle id `com.openai.codex`. Installed 26.908.40834, nixpkgs 26.803.81509 from the same `codex-app-prod` source. Declared in `hm.guiApps`. | no |
| Scroll Reverser | unmanaged | migrate | home-manager | Installed 1.8.2, nixpkgs 1.9. Declared in `hm.guiApps`. | no |
| Arc | unmanaged | remove | none | Moved to Trash 2026-09-13. The nixpkgs `arc-browser` attribute was dropped upstream as unmaintained. | yes |
| HTTPie | unmanaged | remove | none | Moved to Trash 2026-09-13. Available as `pkgs.xh` or `pkgs.httpie` if it is ever needed again. | yes |
| Google Chrome | unmanaged | external | none | MDM-installed by Fleet orbit, like Slack. Reappears at 133.0.6943.54 against the nixpkgs 152.0.7977.76 build. Removed from `hm.guiApps`; Google's updater was never the writer. | no |
| Bitwarden | Mac App Store | migrate | home-manager | nixpkgs `bitwarden-desktop` builds for `aarch64-darwin`. Now declared in `hm.bitwarden`; the root-owned App Store copy is removed after the Home Manager copy is verified. | no |
| Zwift | unmanaged | remove | none | Root-owned bundle removed 2026-09-13. | yes |
| WebStorm | unmanaged | remove | none | Standalone install at `~/Applications/WebStorm.app`; moved to the Trash 2026-09-13 with its `WebStorm2024.2` and `2024.3` state. DataGrip and JetBrains Toolbox remain. | yes |
| Proton Mail leftovers | unmanaged | remove | none | The `Proton Mail Uninstaller.app` and `~/Library/Application Support/Proton Mail` data left behind by the cask removal were moved to the Trash 2026-09-13. | yes |
| Google Docs, Google Sheets, Google Slides | external | keep | external | Not applications: these are `com.google.drivefs.shortcuts.*` shortcuts generated by Google Drive. Never manage them from Nix. | yes |
| Keynote, Numbers, Pages | Mac App Store | keep | mas | Declared through `homebrew.masApps`. No cask and no nixpkgs build exists for any of them, so the App Store is the only source. | no |
| GIPHY CAPTURE | Mac App Store | remove | none | Dropped from `homebrew.masApps` on request 2026-09-13 and left installed but undeclared. Its bundle must be deleted in the same pass, because an installed-but-undeclared App Store app fails `brew bundle cleanup` and aborts activation. | no |
| Tailscale | Mac App Store | keep | mas | Declared through `homebrew.masApps`. The macOS tunnel needs a system extension, and nixpkgs only provides the CLI on Darwin, so Home Manager cannot own the app. The `tailscale-app` cask is the alternative owner; it is declined because it installs through `sudo`, needs the extension re-approved, and is `auto_updates`, so it would control nothing. | no |
| GarageBand, iMovie | Mac App Store | remove | none | Dropped from the declaration and moved to the Trash on 2026-09-13. No cask and no nixpkgs build exists, so no Nix owner was possible. `brew bundle cleanup` **does** report installed App Store apps the Brewfile omits, so undeclaring them without deleting the bundles would abort activation; both were deleted in the same pass. Reclaimed 4.4 GB once the Trash is emptied. | yes |
| CrowdStrike Falcon, SentinelOne, Google Drive | external | keep | external | Organization security and vendor integrations. Never manage them from Nix. | yes |

For every item:

1. Decide `keep` or `remove`.
2. If kept, select exactly one future owner.
3. Check for privileged helpers, drivers, system extensions, or organization policy.
4. Add or change one small ownership group at a time.
5. Build and inspect before activation.
6. Mark the row verified only after the application launches and its integration works.

## Ownership Resume (2026-09-13)

This is the answer to "what is installed right now". Every retained application has exactly one
owner, and nothing is owned twice.

### Tier 1 - Home Manager (12 applications)

Installed into `~/Applications/Home Manager Apps`:

| Application | Module | Notes |
| --- | --- | --- |
| Bitwarden | `hm.bitwarden` | Both hosts. Only Linux pins the SSH agent socket; the App Store copy is gone. |
| Brave Browser | `hm.browser` | |
| ChatGPT | `hm.guiApps` | Darwin only, arm64-only upstream build. |
| Cursor | `hm.agentCursor` | |
| DataGrip | `hm.work` | |
| Discord | `hm.discord` | Nixcord with Vencord. |
| LocalSend | `hm.localSend` | |
| Scroll Reverser | `hm.guiApps` | Darwin only. AppleDouble sidecars are stripped so the code signature stays valid. |
| T3 Code (Nightly) | `hm.agentT3Code` | |
| Visual Studio Code | `hm.agentVscode` | |

The same tier owns every portable CLI tool, the shared Zsh configuration, and the agent configuration,
through `hm.commandLine`, `hm.coding`, `hm.agentCommon`, `hm.agentSkills`, `hm.executor`,
`hm.comma`, `hm.direnv`, `hm.lazydocker`, `hm.plannotator`, and `hm.work`.

### Tier 2 - nix-darwin system state

`darwin.fonts` installs `nerd-fonts.caskaydia-mono` system-wide on both hosts, replacing the
Homebrew font cask. `darwin.macosDefaults` owns appearance, Dock, and Finder, plus the
`CustomUserPreferences` seeds for Rectangle, AltTab, and Scroll Reverser.

### Tier 3 - declarative Homebrew (12 casks, 1 tap)

| Casks | Declared in |
| --- | --- |
| alt-tab, audiorelay, cleanshot, jetbrains-toolbox, moonlight, orbstack, raycast, rectangle | `darwin.homebrew` |
| codex | `darwin.agentCodex` |
| deskflow (with tap `deskflow/tap`) | `darwin.deskflow` |
| ghostty | `darwin.ghostty` |
| rustdesk | `darwin.rustdesk` |

No Homebrew formulae and no Homebrew services are installed.

### Tier 4 - Mac App Store (4 declared)

Keynote, Numbers, Pages, and Tailscale, declared in `homebrew.masApps`. None has a cask or a
nixpkgs build, so no higher tier can take them. See Phase 4 for why Bitwarden is not in this list,
and why GarageBand, iMovie, and GIPHY CAPTURE are neither declared nor owned.

### Tier 5 - external, never touched by activation

Safari, Google Drive for desktop together with the Docs, Sheets, and Slides shortcuts it generates,
CrowdStrike Falcon, SentinelOne, `/Applications/Slack.app`, `/Applications/Google Chrome.app`,
and the MDM enrollment through `welii.mdm.getprimo.com` with its Fleet orbit software installers.

### Completed removals (2026-09-13)

One root-owned bundle duplicated an application Home Manager owns, and was deleted after the
replacement landed:

| Path | Was | Replaced by |
| --- | --- | --- |
| `/Applications/Bitwarden.app` | App Store build | `hm.bitwarden` |

`/Applications/Slack.app` and `/Applications/Google Chrome.app` are deliberately absent from that
table. They were deleted and came back within minutes, because the org's Fleet agent installs them.
Nothing in this repository can own them.

Bitwarden had to be deleted before the switch rather than after it, because an installed but
undeclared App Store application fails the Homebrew cleanup check and aborts activation. That abort
is what the 2026-09-13 switch hit; the bundle is gone now and `mas list` no longer registers it.

GarageBand, iMovie, and GIPHY CAPTURE were dropped from ownership entirely, with nothing replacing
them. GarageBand and iMovie were moved to `~/.Trash/nixfiles-cleanup/` on 2026-09-13; GIPHY CAPTURE
was left installed but undeclared, and can be removed from the App Store UI.

`mas uninstall` was the first choice because it also clears the App Store's record of the install,
but it cannot be driven from an elevated non-interactive context. It reads `SUDO_UID` and
`SUDO_GID` to find the invoking user, calls `/usr/bin/sudo` itself, and then trashes through
`NSFileManager`, which fails as root with `NSCocoaErrorDomain 513` even with `HOME` and
`SUDO_*` set. A plain move into the owner's Trash sidesteps all of it, and because the App Store
receipt lives inside the bundle, removing the bundle deregistered the app anyway.

Do not use `mas uninstall --all` on this machine. It would remove every App Store application,
including Tailscale, Keynote, Numbers, and Pages, which are meant to stay.

Optional extra: `/Library/Application Support/GarageBand` holds 908 MB of GarageBand loop content
that is now orphaned. GarageBand downloads it again if it is ever reinstalled.

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
2. ChatGPT and Scroll Reverser moved from manual installs to `modules/gui-apps.nix`.
3. The Caskaydia Mono Nerd Font moved from a cask to `fonts.packages` in `modules/fonts.nix`,
   which installs it on both hosts.
4. The retained graphical casks are declared in `darwin.homebrew`, which now lists casks only.

Phase 3 - unmanaged applications (done 2026-09-13)

1. Arc, HTTPie, Zwift, WebStorm, and the Proton Mail leftovers moved to the Trash, and the Brave
   Slack web-app shortcut was deleted.
2. Google Docs/Sheets/Slides are `com.google.drivefs.shortcuts.*` Drive placeholders rather than
   applications, so they stay untouched.
3. Slack and Google Chrome turned out to be MDM-installed rather than manual copies, so they were
   removed from `hm.guiApps` and moved to the do-not-touch list; see TODO.md.

Phase 4 - Mac App Store (done 2026-09-13)

1. Four App Store applications are declared through `homebrew.masApps` in `darwin.homebrew`:
   Keynote, Numbers, Pages, and Tailscale. None of them has a cask or a nixpkgs
   build, so the App Store is genuinely the only source; that is the case `masApps` exists for.
2. Bitwarden is deliberately absent from that list. nixpkgs builds `bitwarden-desktop` for
   `aarch64-darwin`, and Home Manager outranks the App Store in the ownership tiers, so
   `hm.bitwarden` owns it on both hosts instead. Keeping one owner also keeps the desktop's SSH
   agent honest, because the agent ships inside the application bundle.
3. GarageBand and iMovie are also absent, and were removed on 2026-09-13. No Nix owner was possible
   for either, and both were deleted rather than merely undeclared, because
   `brew bundle cleanup` does report installed App Store applications that the Brewfile omits.
4. Tailscale was evaluated for Home Manager and cannot go there: nixpkgs ships only the CLI on
   Darwin (`tailscale`, `tailscaled`, `get-authkey`, no `.app`), because the macOS tunnel needs
   a system extension that Nix cannot install. Homebrew has a standalone cask, `tailscale-app`,
   and Homebrew's plain `tailscale` is the CLI formula, not the GUI. The cask is declined: it is
   the same version the App Store build already runs, it installs through a `.pkg` that needs
   `sudo` and a re-approved system extension, and it is marked `auto_updates`, so moving it would
   trade a working extension for no declarative gain.
5. Declaring them is not optional tidiness. `brew bundle cleanup` detects an installed App Store
   application that the Brewfile omits and returns exit 1, and nix-darwin's `"check"` mode treats
   that exit code as a hard failure and aborts activation with "found Homebrew packages not listed
   in the Brewfile". Under `cleanup = "uninstall"` the same detection force-uninstalls the app.
   This is what blocked the 2026-09-13 activation: Bitwarden was still installed from the App Store
   while the Brewfile had dropped it in favour of Home Manager, so the switch refused to run until
   the App Store copy was deleted. Declaring App Store applications therefore keeps them
   documented, reproducible on a fresh machine, and verified by `brew bundle check`, without
   leaving a landmine that blocks the next activation.

   The tradeoff is one hard limitation: removing an entry from `masApps` never uninstalls the
   application, even under `cleanup = "uninstall"`, so App Store removals always stay manual. The
   two facts together mean an App Store application is best declared while installed, and its
   bundle deleted in the same change that drops its entry.
6. `brew bundle check` flags Tailscale as unmet on this machine. That is a pending App
   Store update, not a missing application, and it cannot block activation:
   `onActivation.cleanup = "check"` only reports packages that are installed but undeclared.

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

Run the switch from the terminal emulator you normally use. Home Manager's app copying needs the
macOS App Management permission (`kTCCServiceSystemPolicyAppBundles`), and macOS records it against
the process responsible for the activation rather than against the user. A terminal that holds the
grant completes the switch; a process without it aborts with "permission denied when trying to
update apps" even though the flake is fine. The check resets the service with `tccutil reset
SystemPolicyAppBundles` before it fails, so accept the App Management prompt the next run raises and
add the terminal under System Settings > Privacy & Security > App Management if no prompt appears.
See Pattern 8 in `docs/research/macos-nix-darwin-patterns.md`.

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
