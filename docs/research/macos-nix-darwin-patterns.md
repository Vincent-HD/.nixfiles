# macOS + nix-darwin: upstream patterns and how this repository maps onto them

Research notes gathered while migrating `macbook-pro` from manual installs and Homebrew to
declarative ownership. Scope: how other nix-darwin / Home Manager configurations solve the same
problems, and which of those patterns this repository uses.

## The problem

macOS cannot be configured from nixpkgs alone. Three things push packages outside Home Manager:

1. **GUI applications with no nixpkgs build.** Many casks ship a signed bundle, a notarized
   installer, or a vendor updater that nixpkgs does not reproduce.
2. **System extensions and privileged helpers.** Network filters, camera extensions, audio drivers,
   and VPN tunnels install via `.pkg` and need root. Nix has no mechanism for this.
3. **Self-updating applications.** Raycast, JetBrains Toolbox, and CleanShot X update themselves,
   so Nix-managed versions fight the vendor updater.

The community answer is a deliberate split of ownership rather than one manager for everything.

## Ownership tiers

The order below is the one this repository follows, highest priority first.

| Tier | Owner | Use for |
| --- | --- | --- |
| 1 | Home Manager (`home.packages`, `programs.*`) | Anything with a working nixpkgs build, especially anything also needed on Linux |
| 2 | nix-darwin system modules (`environment.systemPackages`, `fonts.packages`, `system.defaults`) | Machine-wide state: fonts, defaults, LaunchDaemons, users |
| 3 | Homebrew, declared through nix-darwin | GUI apps, self-updating apps, and `.pkg` installers with no nixpkgs build |
| 4 | Mac App Store, declared through `homebrew.masApps` | Apple-only apps with no other source |
| 5 | Manual / vendor / MDM | Things that must stay outside automation entirely |

Tier 1 wins whenever it can, because a single code path shared with Linux is less to maintain. A
package only falls to tier 3 when nixpkgs genuinely cannot supply it, not when the cask is merely
more convenient.

## Pattern 1: nix-darwin's Homebrew module generates a Brewfile

nix-darwin's `homebrew` module does not manage Homebrew state directly. It renders a Brewfile from
Nix options and hands it to `brew bundle` during activation. Relevant options:

- `homebrew.casks`, `homebrew.formulae`, `homebrew.taps`, `homebrew.masApps`
- `homebrew.greedyCasks` for casks that are not in the Homebrew API
- `homebrew.extraEnv` for per-run environment such as `HOMEBREW_NO_ANALYTICS`
- `homebrew.onActivation.cleanup` with `none`, `check`, `uninstall`, or `zap`

`cleanup = "check"` runs `brew bundle cleanup` and **aborts activation** when something is
installed but undeclared, which makes drift visible. That is why this repository declared every
retained cask before flipping it on. `"uninstall"` would remove undeclared packages and `"zap"`
would also remove their data; both are avoided here because the machine is work-managed and hosts
external security agents.

Homebrew 7 also expects tap trust, which nix-darwin satisfies by writing `trusted: true` on casks
from third-party taps.

## Pattern 2: nix-homebrew for declarative Homebrew itself, and its bootstrap problem

`nix-darwin`'s module assumes Homebrew is already installed. `github:zhaofengli/nix-homebrew`
closes that gap: it installs Homebrew itself through Nix, supports multiple taps declaratively, and
lets the Homebrew prefix be reproduced from the flake rather than from a machine-local installer.

This repository does **not** use it. The Mac runs Apple Silicon Homebrew at the default
`/opt/homebrew` prefix installed the usual way, and the migration deliberately kept the Nix
installer and Homebrew bootstrapping untouched so the change stayed reviewable. A Nix-managed
Homebrew prefix remains the natural follow-up if a second Mac ever needs to be reproduced from
scratch.

## Pattern 3: `masApps` and the `mas` version trap

`homebrew.masApps` declares App Store applications in the same Brewfile, and nix-darwin injects
nixpkgs' `mas` into `PATH` when it runs `brew bundle`, so `mas` does not need to come from
Homebrew.

This option has a real history of breakage. nixpkgs once shipped `mas` 2.2.2 while Homebrew moved
from `mas install` to `mas get`, which made activation fail outright
([nix-darwin#1722](https://github.com/LnL1/nix-darwin/issues/1722), fixed by updating nixpkgs).
That is the general risk with masApps: the CLI is a separate moving part from Homebrew.

Verified on this machine: nixpkgs supplies `mas` 7.0.0, and `mas --help` lists both `get` and
`install`, so the historical failure mode is gone. `brew bundle check` also correctly reports
installed App Store apps as satisfied.

A second property matters more than the documentation suggests: `brew bundle cleanup` **does**
consider installed App Store applications. An App Store app that is installed but absent from
`masApps` makes `cleanup` return exit 1, and nix-darwin's `onActivation.cleanup = "check"` treats
exit 1 as a hard failure and aborts activation with "found Homebrew packages not listed in the
Brewfile". This is the one place App Store applications are not invisible to nix-darwin. It is
easy to get wrong when moving a MAS app to Home Manager: dropping the `masApps` entry while the App
Store copy is still on disk blocks the very activation that would install the replacement. Delete
the store copy first, or in the same pass.

A third documented limitation: **removing an entry from `masApps` does not uninstall the
application**, even with `cleanup = "uninstall"`. App Store apps must be removed through the App
Store, so an entry deleted here leaves a manual cleanup behind.

A fourth trap appeared while removing two App Store apps. `mas uninstall` cannot be driven from an
elevated non-interactive context: it reads `SUDO_UID` and `SUDO_GID` to work out which user it is
acting for, shells out to `/usr/bin/sudo` itself, and then trashes the bundle through
`NSFileManager`. Run as root without a real `sudo` parent it fails on the missing uid, and with
`HOME` and `SUDO_*` filled in it still fails with `NSCocoaErrorDomain 513` because the trash
operation needs the user's own session. Run it from an interactive shell where `sudo` is genuine,
or move the bundle into the owner's Trash directly. Deleting the bundle is sufficient either way:
the App Store receipt lives inside it, so the app stops being registered as installed.

A fifth trap, and the one that actually broke activation here, is `mas upgrade`. It is not reached
through the masApps preinstall path, which is why `--no-upgrade` alone does not prevent it:
`Homebrew::Bundle::MacAppStore.batch_installable?` always returns true, so masApps are collected
into a single batch, and `batch_install_package_type!` partitions that batch on
`preinstall!` alone. `preinstall!` returns true for an installed-but-outdated app as long as
`no_upgrade` is false, and `install_batch!` then calls `Bundle.system(mas, "upgrade", <ids>)`.
`mas upgrade` shells out to `/usr/bin/sudo` internally, and nix-darwin already runs `brew bundle`
through `sudo --user=<user> --set-home`, so the inner prompt has no terminal to read and the whole
switch dies with "sudo: a terminal is required to read the password ... Installing Tailscale has
failed!". With `no_upgrade` true, `preinstall!` returns false for every up-to-date-or-not installed
app, `install_batch!` is never called, and activation leaves outdated App Store apps alone.

So `homebrew.onActivation.upgrade = true` is a trap on a machine that uses `masApps`: one pending
App Store update, anywhere, aborts every subsequent activation. It also matches the module's own
warning, which fires when `autoUpdate` or `cleanup` is set, that Homebrew no longer upgrades during
activation by default. Leaving `upgrade` at its default `false` keeps activation idempotent, and
App Store upgrades become a deliberate manual step.

## Pattern 4: `system.defaults.CustomUserPreferences` for third-party settings

`system.defaults` only models a fixed set of Apple domains. For third-party applications,
nix-darwin exposes `system.defaults.CustomUserPreferences`, which accepts an arbitrary domain tree
and writes it with `defaults write` as the primary user during activation.

Two properties matter when using it:

- It is a **seed, not enforcement**. A running application holds its own copy and overwrites the
  value when it exits, so the application must be quit before switching.
- Only stable, user-intended keys should be declared. Vendor bookkeeping (Sparkle's `SU*`,
  window frames, migration markers) belongs to the application.

This repository uses it for Rectangle, AltTab, and Scroll Reverser. Raycast is excluded on purpose:
its defaults domain is internal bookkeeping keyed by extension UUIDs, its real state lives in a
SQLite store under Application Support, and it syncs through its own account.

## Pattern 5: user LaunchAgents versus system LaunchDaemons

`launchd.user.agents.<name>` installs a per-user agent into `~/Library/LaunchAgents`, which is
what Home Manager and nix-darwin use for user services. System daemons that run as root use
`launchd.daemons`. Getting this wrong is a common source of "the service does not start" reports,
because a user agent cannot perform privileged work.

Related: Homebrew's own services are labelled `homebrew.mxcl.<formula>`, and Homebrew 7 moved new
and restarted services to `sh.brew.<formula>`. Leftover `homebrew.mxcl.*` agents can survive the
formula they came from, so a stale agent pointing at a deleted prefix binary is worth removing.

## Pattern 6: `system.primaryUser`

`system.primaryUser` tells nix-darwin which account owns user-level activation work, which is what
makes `system.defaults` and app copying land in the right home directory. It coordinates with
`home-manager.users.<name>`. Both are set on this host.

## Pattern 7: when an application must stay outside automation

Some software is not migratable and trying is a mistake:

- **System extensions.** Tailscale on macOS reaches the network through a system extension. nixpkgs
  ships only the CLI on Darwin (`tailscale`, `tailscaled`, `get-authkey`, no `.app`), so Home
  Manager cannot own the menu-bar application. A standalone cask does exist (`tailscale-app`, a
  `.pkg` that also installs the extension), but this repository keeps the App Store build: the two
  distribute the same version, the cask still installs through `sudo` and needs the extension
  re-approved, and its `auto_updates` flag means Homebrew would control nothing. Note also that
  Homebrew's `tailscale` is the CLI formula while `tailscale-app` is the GUI cask.
- **Privileged helpers.** VPN clients, remote-desktop agents, and endpoint security.
- **Endpoint security and MDM.** CrowdStrike Falcon, SentinelOne, and Google Drive for desktop are
  managed externally and must never be touched by activation.

## Pattern 8: the App Management grant belongs to the launching process

Home Manager's Darwin app copying needs the `SystemPolicyAppBundles` TCC service, which macOS
presents as App Management in System Settings > Privacy & Security. Copying a `.app` into
`~/Applications/Home Manager Apps` and touching a file inside it both require it, because
`/usr/bin/touch "$appBundle/.DS_Store"` is how `targets.darwin.copyApps` probes for the grant
before it copies anything.

The grant is recorded against the process responsible for the activation, not against the user or
the Nix store. A terminal emulator that has been granted App Management can run the switch; an
automation shell with no such grant cannot, and fails with "permission denied when trying to
update apps, aborting activation" while the same command succeeds by hand. This is why a switch
can pass in one launcher and fail in another with an identical flake.

Two practical consequences:

1. Run `darwin-rebuild switch` from the terminal you actually use, and grant App Management to it
   when macOS first prompts.
2. `targets.darwin.copyApps.enableChecks` can be turned off to skip the probe. That is a debugging
   escape hatch, not a fix: activation then fails later with a raw permission error instead of a
   readable one, and the apps still will not copy.

One sharp edge makes this confusing to debug. The failure branch runs `tccutil reset
SystemPolicyAppBundles` **before** it gives up, so every failed activation clears the grant for
every process, not just the one that failed. A terminal that completed a switch an hour ago can
fail the next one with no configuration change, because an intervening failure from some other
launcher wiped its grant. When this error appears, the fix is to accept the prompt, not to hunt for
a flake regression.

## Homebrew 7.0.0 changes that affect this setup

Released 2026-09-13. The items that matter here:

- **Self-updating casks are respected.** `brew upgrade` skips incompatible casks, and both it and
  `brew outdated` honour `HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS`, preserving the opt-out that
  self-updating applications rely on. Relevant because this host used to run with
  `upgrade = true`; it no longer does, see Pattern 3.
- **Cleaner uninstalls.** `brew uninstall` avoids needless password prompts when files are already
  owned by the current user, and drops records for casks missing from the API.
- **Faster batch installs.** `brew bundle` benefits from the same shared preparation and download
  work as multi-package commands, which shortens activation.
- **Structured diagnostics.** `brew doctor --json` and `brew install --dry-run` are available for
  scripted checks.
- **Built-in vulnerability scanning.** `brew vulns` checks installed formulae against OSV.dev with
  no extra tap or gem.
- **Cask install hooks.** `preflight` and `postflight` Ruby blocks are deprecated in favour of
  `*_steps`; officially irrelevant here because this repository does not author casks.
- **Platform support.** Sequoia 15, Tahoe 26, and Golden Gate 27 are Tier 1 on Apple Silicon. Intel
  macOS moved to Tier 3 and macOS 10.15 is unsupported; neither affects this machine (macOS 26.5.1,
  Apple Silicon).

Verified against the Homebrew actually installed on this machine rather than the announcement alone:
it already runs **7.0.1**, Apple Silicon at `/opt/homebrew`. `Library/Homebrew/env_config.rb`
defines `HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS`, `Library/Homebrew/service.rb` writes both the
`homebrew.mxcl.<formula>` and `sh.brew.<formula>` labels, and `brew vulns`, `brew doctor
--json`, and `brew install --dry-run` are all present. The machine's last activation already ran
under 7.x, which is why it printed JSON API downloads and `Already trusted tap: deskflow/tap`.
Because this configuration installs casks and no formulae, the sandboxed-formula-build changes in 7
do not apply here. `brew config` also reports `Core tap: N/A`, which is expected: `brew bundle`
resolves casks through the JSON API and has no core tap checked out.

## Sources

- Homebrew 7.0.0 release notes: <https://brew.sh/2026/09/13/homebrew-7.0.0/>
- nix-darwin repository and wiki, including the homebrew module and FAQ:
  <https://github.com/LnL1/nix-darwin>
- `masApps` breakage from the `mas` version lag:
  <https://github.com/LnL1/nix-darwin/issues/1722>
- Homebrew's `mas install` to `mas get` change: <https://github.com/Homebrew/brew/issues/21559>
- Declarative Homebrew installation for nix-darwin: <https://github.com/zhaofengli/nix-homebrew>
- Community write-ups on macOS + nix-darwin practice, for further reading:
  <https://xyno.space/post/darwin-nix-best-practices> and
  <https://www.jacobcolvin.com/blog/2025/04/28/darwin-nix-homebrew/>

## How this repository maps onto the patterns

| Concern | This repository |
| --- | --- |
| Portable CLI tools | Home Manager (`hm.commandLine`, `hm.coding`) on both hosts |
| Portable GUI apps with nixpkgs builds | Home Manager (`hm.guiApps`), including ChatGPT and Scroll Reverser |
| Fonts | `fonts.packages` through `modules/fonts.nix` on both hosts |
| Third-party app settings | `system.defaults.CustomUserPreferences` for Rectangle, AltTab, Scroll Reverser |
| Self-updating and privileged GUI apps | Homebrew casks declared in `darwin.homebrew` and per-feature modules |
| App Store applications | `homebrew.masApps` in `darwin.homebrew` |
| Drift detection | `homebrew.onActivation.cleanup = "check"` |
| Homebrew bootstrapping | Machine-local Apple Silicon install; `nix-homebrew` not adopted |
| Endpoint security, MDM, Google Drive | External; never touched by activation |

See `docs/MACOS_MIGRATION.md` for the live inventory and `TODO.md` for the remaining work.
