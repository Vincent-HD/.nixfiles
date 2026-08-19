# TODO

This file tracks known technical debt that is intentionally deferred. Entries should describe the
current compromise, the desired end state, and how to verify the replacement before removing the
existing implementation.

## Consolidate Shell Configuration Around Zsh

### Context

The Mac login shell is Zsh, but shell configuration is currently split:

- `modules/coding/default.nix` enables Bash and initializes Fnm only for Bash on Linux.
- `modules/darwin/development.nix` contains a Darwin-specific Zsh configuration instead of a shared
  cross-platform Zsh feature.
- Some shell integrations remain in manually managed startup files during the incremental macOS
  migration.

This leaves behavior inconsistent between Linux and Darwin and keeps some development tooling tied
to Bash or Homebrew.

### Desired End State

- Create one reusable Home Manager Zsh feature module shared by Linux and Darwin.
- Move shared aliases and shell integrations into that module.
- Initialize the Nix-managed Fnm package for Zsh on both hosts.
- Migrate Starship, Zoxide, McFly, and other existing interactive integrations into Home Manager
  without losing their current behavior or history.
- Separate Darwin-only integrations such as OrbStack from shared Zsh configuration.
- Remove obsolete Homebrew paths and manually managed Zsh startup content after each replacement is
  tested.
- Remove Bash-only interactive configuration from `hm.coding`; retain Bash only where required for
  compatibility or non-interactive scripts.

### Verification

- New Zsh login and interactive shells start without errors on both hosts.
- `fnm`, Starship, Zoxide, McFly, aliases, completion, autosuggestions, and syntax highlighting
  work on both hosts.
- Darwin and Linux share the same declarative Zsh configuration.
- Home Manager owns the intended Zsh files without silently discarding existing behavior.
- NixOS rebuilds and Darwin rebuilds both pass before removing old startup-file content.
