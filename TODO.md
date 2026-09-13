# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Remove the Manual Google Chrome Copy and Calm Its Updater

### Context

`pkgs.google-chrome` is declared in `hm.guiApps` for Darwin, so Home Manager now owns Chrome. The
root-owned `/Applications/Google Chrome.app` (133.0.6943.54) is still on disk, and it came back
once already: a removal was followed minutes later by Google's updater stack running, and the bundle
was present again with a fresh birth time.

The restore path is Google's own updater, which Nix does not control:

- `/Library/LaunchDaemons/com.google.GoogleUpdater.wake.system.plist` runs
  `GoogleUpdater --wake-all --system` every 3600 seconds and is loaded.
- `/Library/Application Support/Google/GoogleUpdater` keeps its own state and staged packages.
- The legacy Keystone plists (`com.google.keystone.{agent,daemon,xpcservice}`) are installed but
  currently unloaded.

### Desired End State

- `/Applications/Google Chrome.app` is gone and only the Home Manager copy remains.
- Google's updater no longer restores a Chrome bundle behind Nix's back.
- Organization agents still work: Chrome reads their native messaging hosts from the
  bundle-independent `/Library/Google/Chrome/NativeMessagingHosts` directory, so a Nix-provided
  bundle keeps SentinelOne and CrowdStrike integration.
- Mac App Store applications are either declared through `homebrew.masApps` or explicitly left to
  the App Store; `brew bundle cleanup` ignores them either way.

### Verification

- `ls -d /Applications/Google\ Chrome.app` stays absent an hour after removal, past one wake
  interval.
- `brew bundle cleanup` exits 0 with no output.
- The SentinelOne and CrowdStrike browser extensions still load in the Home Manager Chrome.

### Risk

Google Drive for desktop is on the do-not-touch list and may share Google's updater with Chrome.
Disabling that updater can stop Drive's automatic updates, so test Drive after the change. If Drive
breaks, fall back to the Homebrew `google-chrome` cask, which keeps Google's updater in charge.
