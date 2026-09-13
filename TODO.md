# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Slack and Chrome Are Reinstalled by the Corporate MDM

### Context

Earlier revisions of this file blamed Google's updater for recreating `/Applications/Google
Chrome.app`. That was wrong. The real owner is the Fleet MDM agent at `/opt/orbit`, and it
reinstalls Slack the same way.

Both bundles reappear after `sudo rm -rf` at versions *older* than the Home Manager copies, which
no updater does: Slack 4.42.117 against 4.51.180, Chrome 133.0.6943.54 against 152.0.7977.76. Each
reappearance is preceded by a DMG mount and an orbit software-installer run. The evidence:

- A DMG labelled `Slack` mounts (`hfs: mounted Slack on device disk5s1`), then a second image for
  Chrome, with root-owned staging directories under `/tmp/dmg_mount_*`.
- `sentineld` logs `Monitoring of path '/private/tmp/.../install-script.sh' failed` at the same
  second, which is how orbit executes a downloaded installer.
- `/opt/orbit/bin/orbit/macos/stable/orbit` contains `install-script`, `post-install-script`,
  `Installation failed after %d attempts`, and the symbol
  `github.com/fleetdm/fleet/v4/server/fleet.(*OrbitClient).DownloadSoftwareInstaller`.
- The machine is MDM-enrolled (User Approved) through `welii.mdm.getprimo.com`. Neither bundle has a
  Homebrew cask receipt, and `pkgutil --pkgs` has no `com.google.Chrome`, so Homebrew and a plain
  pkg install are both ruled out.
- `com.google.GoogleUpdater.wake.system` is `disabled` in the system launchd domain, and
  `managedappdistributiond` only observed the bundle's modification date change. Neither is the
  writer.

These are Fleet self-service software packages, not MDM-whitelisted apps:
`com.apple.servicemanagement` whitelists SentinelOne bundle ids only.

### Status (2026-09-13)

The Home Manager copies of Slack and Chrome were removed from `hm.guiApps`. Managing them was
pointless: the duplicate is org-owned, it is not removable through Nix, and `homebrew` cannot see it
either. Both `/Applications/Slack.app` and `/Applications/Google Chrome.app` now sit on the
do-not-touch list beside CrowdStrike, SentinelOne, Google Drive, and the MDM itself.

### Desired End State

- No Home Manager or Homebrew entry claims Slack or Chrome on Darwin.
- The org-installed bundles are left in place and are not counted as migration debt.
- If either app is wanted in a Nix-managed form, it is launched from the vendor's own installer or
  from the org package, not duplicated.

### Verification

- `rg -n 'slack|google-chrome' modules/` returns no package declarations for Darwin.
- `brew bundle check` stays clean: neither bundle is a Homebrew-managed cask.
- A `sudo rm -rf` of either bundle is followed by reappearance within minutes, which is the
  expected MDM behaviour and not a regression.

### Risk

The org can push a different version of either app at any time, including one older than what the
user would otherwise run. Nothing in this repository can control that. Report version problems to
the org rather than working around them locally.

## Convert the Shared Shell Configuration to Zsh Only

### Context

The shared shell module was written for Linux first, so it enables Bash integration alongside Zsh
for every tool that offers one: Atuin, fzf, Starship, yazi, and zoxide all set
`enableBashIntegration = true` in `modules/command-line/default.nix`. Home Manager therefore
generates Bash rc files and Bash startup hooks on both hosts.

On macOS this is dead weight with a sharp edge. The system Bash is 3.2, the generated hooks are
never exercised by an interactive session, and the Agent Skills scripts under
`modules/agents/assets/skills/*/scripts/` still carry `#!/usr/bin/env bash` shebangs while the
documented workflow is `zsh -lic`.

### Desired End State

- `enableBashIntegration` is dropped from the shared module, leaving Zsh as the only managed shell.
- The Agent Skills helper scripts run under Zsh, or are rewritten as POSIX `sh` where they do not
  need Zsh features, so a `zsh -lic` invocation and a direct execution agree.
- No Home Manager Bash rc files are generated on either host.

### Verification

- `rg -n 'enableBashIntegration' modules/` returns nothing.
- A fresh `darwin-rebuild switch` and `nixos-rebuild switch` both evaluate and activate.
- `zsh -lic 'command -v atuin fzf starship yazi zoxide'` still resolves every tool.
- Each skills script still runs after the shebang change: run the `jj-auto-revise` status script and
  the `jj-resplit-stack` inventory script directly.

### Risk

Anything that shells out to `bash -c` for these tools stops getting their shell integration. The
affected integration is cosmetic for all five tools, so the loss is bounded; confirm with the
verification commands before removing the flags.

## Remove the Duplicate App Store Bitwarden

### Context

Bitwarden was installed twice: the App Store build at `/Applications/Bitwarden.app` (root-owned,
installed 2025-08-25) and `pkgs.bitwarden-desktop` through `hm.bitwarden`. Home Manager outranks
the App Store in the ownership tiers, and Bitwarden's SSH agent is a setting inside the installed
bundle, so the Nix-managed copy is the one that should survive. Two copies also meant two
registrations for the `bitwarden://` URL scheme and two candidate locations for the agent socket.

The App Store build had to go **before** the switch, not after it. `brew bundle cleanup` reports an
installed App Store application that the Brewfile omits, and `onActivation.cleanup = "check"` aborts
activation on that report, so dropping the `masApps` entry while the store copy was still on disk
blocked the switch outright. The bundle was deleted on 2026-09-13; because the App Store receipt
lives inside the bundle, `mas list` stopped registering the app at the same time.

### Status (2026-09-13)

The App Store bundle is gone and the `masApps` entry is gone. What remains is the activation that
installs the Home Manager copy, and Bitwarden is uninstalled on this machine until it runs.

The activation no longer stops on the Homebrew check: `homebrew.onActivation.upgrade` was `true`,
which ran `brew bundle` without `--no-upgrade`, sent the outdated App Store Tailscale through
`mas upgrade`, and died on the `sudo` prompt `mas` opens internally. It is `false` now, and the
Brewfile check passes. The remaining stop is Home Manager's App Management check, which is a
per-process macOS permission rather than a repository problem; see Pattern 8 in
`docs/research/macos-nix-darwin-patterns.md`.

### Desired End State

- Only `~/Applications/Home Manager Apps/Bitwarden.app` is installed.

### Verification

- `ls -d /Applications/Bitwarden.app` reports no such file. Done.
- `darwin-rebuild switch` completes instead of aborting on the Homebrew or App Management check.
- The Home Manager Bitwarden launches and unlocks, and `ssh-add -l` still lists keys served by its
  SSH agent.
- `open "bitwarden://"` resolves to the Home Manager bundle.

### Why this is manual

`homebrew.masApps` cannot uninstall it: removing an entry from `masApps` never removes the
application, even under `onActivation.cleanup = "uninstall"`, because the App Store owns the
install. The removal stays a `sudo` step:

```bash
sudo rm -rf /Applications/Bitwarden.app
```
