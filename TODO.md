# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Finish the macOS Cask Cleanup

### Context

`homebrew.onActivation.cleanup` is now `"check"` on `macbook-pro`, so nix-darwin runs
`brew bundle cleanup` during activation and aborts when an installed cask is undeclared. Every
retained cask is declared by a composed module, but two abandoned casks are still installed and
therefore undeclared, and `brew uninstall` for them needs a password the agent shell cannot supply:

- `obs` (ships a camera system extension)
- `teamviewer` (installs a privileged helper)

**The next `darwin-rebuild switch` aborts until they are removed.** Run
`brew uninstall --cask obs teamviewer` before the next switch.

### Desired End State

- `brew uninstall --cask obs teamviewer` has run, so `brew list --cask` shows only declared casks.
- The Brave Slack web-app shortcut at `~/Applications/Brave Browser Apps.localized/Slack.app` is
  deleted; the Home Manager desktop app replaces it.
- Root-owned leftovers `/Applications/Google Chrome.app` and `/Applications/Zwift.app` are gone.

### Verification

- `brew bundle cleanup` exits 0 with no output.
- `sudo darwin-rebuild switch --flake .#macbook-pro` completes without the cleanup abort.
