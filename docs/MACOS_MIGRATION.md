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

Replace the placeholder rows with the current applications. Do not copy dependency formulae into
the table; record only intentionally installed leaves and applications.

| Application | Installed owner | Decision | Future owner | Action or caveat | Verified |
| --- | --- | --- | --- | --- | --- |
| _Fill on the Mac_ |  | keep/remove | home-manager/homebrew/mas/external |  | no |

For every item:

1. Decide `keep` or `remove`.
2. If kept, select exactly one future owner.
3. Check for privileged helpers, drivers, system extensions, or organization policy.
4. Add or change one small ownership group at a time.
5. Build and inspect before activation.
6. Mark the row verified only after the application launches and its integration works.

## Likely Items To Recheck

The previous Mac inventory contained the following candidates. This is a checklist for discovery,
not a desired package list:

- Native apps: AltTab, AudioRelay, BlackHole, Bruno, CleanShot, DBeaver, Ghostty, GitButler,
  Insomnia, JetBrains Toolbox, Moonlight, OBS, OrbStack, Proton Mail, Raycast, Rectangle, Slack,
  Tabby, TeamViewer, and Zwift
- Mac App Store: Bitwarden, GarageBand, GIPHY Capture, iMovie, Keynote, Numbers, Pages, and Tailscale
- Portable formulae that may now be redundant: AWS CLI, Btop, Docker CLI/Compose, Doppler, Fnm,
  Git, Hub, Hurl, jq, lazydocker, libpq, McFly, Starship, The Fuck, watch, Zoxide, and Zsh plugins
- Vendor or external integrations: Google Drive, organization security agents, TeamViewer helpers,
  Google updater components, audio drivers, and system extensions

Confirm every item against the live machine. It may have been installed, removed, renamed, or
replaced since the previous inventory.

## Migration Order

1. Reconcile portable formulae already supplied by Home Manager.
2. Declare retained native GUI applications as Homebrew casks or MAS applications.
3. Resolve duplicate ownership, especially editors, browsers, Discord, Bitwarden, and JetBrains
   applications.
4. Keep invasive vendor and organization integrations external.
5. Verify shell startup, OrbStack, work projects, Spotlight, LaunchAgents, and application launch.
6. Only after every retained Homebrew item is declared, change cleanup from `"none"` to `"check"`.
7. Consider `"uninstall"` only in a later task after repeated successful checks. Do not use
   `"zap"` on this work-managed machine.

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
