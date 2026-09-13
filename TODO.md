# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Remove the Manual Google Chrome Copy

### Context

`pkgs.google-chrome` is declared in `hm.guiApps` for Darwin, so Home Manager now owns Chrome. The
root-owned `/Applications/Google Chrome.app` (133.0.6943.54) is still on disk, and it came back
once already: a removal was followed minutes later by Google's updater stack running, and the bundle
was present again with a fresh birth time.

### Status (2026-09-13)

The restore path is closed. `com.google.GoogleUpdater.wake.system` reports `disabled` in the
system launchd domain, so the hourly `GoogleUpdater --wake-all --system` job that staged a
replacement bundle no longer runs, and the legacy Keystone plists
(`com.google.keystone.{agent,daemon,xpcservice}`) stay unloaded. `/Library/Application
Support/Google/GoogleUpdater` still keeps its own state and staged packages, but nothing launches
them any more. Only the `sudo` removal remains:

```bash
sudo rm -rf "/Applications/Google Chrome.app"
```

### Desired End State

- `/Applications/Google Chrome.app` is gone and only the Home Manager copy remains.
- Google's updater no longer restores a Chrome bundle behind Nix's back.
- Organization agents still work: Chrome reads their native messaging hosts from the
  bundle-independent `/Library/Google/Chrome/NativeMessagingHosts` directory, so a Nix-provided
  bundle keeps SentinelOne and CrowdStrike integration.

### Verification

- `ls -d /Applications/Google\ Chrome.app` stays absent an hour after removal, past one wake
  interval.
- `brew bundle cleanup` exits 0 with no output.
- The SentinelOne and CrowdStrike browser extensions still load in the Home Manager Chrome.
- Launching Chrome from Spotlight or the Dock resolves to
  `~/Applications/Home Manager Apps/Google Chrome.app`.

### Risk

Google Drive for desktop is on the do-not-touch list and shares Google's updater stack with Chrome.
Disabling that updater also stops Drive from updating itself, so test Drive after the change. If
Drive breaks, re-enable `com.google.GoogleUpdater.wake.system` and fall back to the Homebrew
`google-chrome` cask, which keeps Google's updater in charge.

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

### Desired End State

- Only `~/Applications/Home Manager Apps/Bitwarden.app` is installed.

### Verification

- `ls -d /Applications/Bitwarden.app` reports no such file. Done.
- `darwin-rebuild switch` completes instead of aborting on the Homebrew check.
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
