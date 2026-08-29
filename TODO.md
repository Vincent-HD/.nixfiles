# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Reconcile the Dormant Darwin Homebrew Module

### Context

The active macOS composition imports the shared `hm.commandLine` and `hm.coding` modules and now
composes `darwin.macosDefaults`. The duplicated Darwin development module was removed after its
portable behavior moved into the shared modules. One older migration module remains auto-discovered
but is not composed:

- `modules/darwin/homebrew.nix`

It contains the pre-migration Homebrew formula, cask, and Mac App Store list. Enabling it directly
would duplicate applications already owned by Home Manager. Keep it inactive until a fresh live Mac
inventory decides which remaining applications to keep, remove, or migrate.

### Desired End State

- Re-inventory Homebrew, Mac App Store, manual applications, and privileged components on the Mac.
- Assign one owner to each retained application: Home Manager, declarative Homebrew/MAS, or external.
- Move only the selected declarations into composed feature modules.
- Delete `modules/darwin/homebrew.nix` after it contains no unique migration information.

### Verification

- `rg 'darwin\.homebrew' hosts modules` finds either explicit composition or no remaining definition.
- The generated Brewfile and relevant `system.defaults` match the intended live macOS state.
- A new Zsh login shell has the same shared integrations as Linux and preserves OrbStack integration.
- Linux and Darwin evaluations pass before removing the old files.
