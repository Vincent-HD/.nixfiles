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

### Status (2026-09-13)

The live inventory is captured in `docs/MACOS_MIGRATION.md`. Phase 1 removed the duplicate
`visual-studio-code`, `cursor`, and `codex-app` casks. The remaining 25 casks are still
undeclared, so this module still holds unique migration information and must stay.

## Declare the Remaining macOS Applications

### Context

`homebrew.onActivation.cleanup` is still `"none"` on `macbook-pro`, so the 25 installed casks
drift freely. Setting it to `"check"` now would break activation: nix-darwin runs
`brew bundle cleanup` and aborts with `found Homebrew packages not listed in the Brewfile`.
Cleanup can only be tightened after every retained package is declared.

### Desired End State

- Every retained cask, font, and Mac App Store application is declared by exactly one composed module.
- `brew bundle cleanup` reports nothing, so `cleanup = "check"` can be enabled.
- Unmanaged drag-and-drop installs (Arc, ChatGPT, Google Chrome, Google Docs/Sheets/Slides, HTTPie,
  Scroll Reverser, Slack, Zwift) are each classified as cask, removed, or external.
- The Caskaydia Mono Nerd Font moves from a cask to `fonts.packages`.

### Verification

- `brew bundle cleanup` prints no packages.
- `nix eval .#darwinConfigurations.macbook-pro.config.homebrew.brewfile --raw` lists every retained
  cask plus the tap.
- After flipping to `"check"`, `sudo darwin-rebuild switch --flake .#macbook-pro` completes
  without the cleanup abort.
