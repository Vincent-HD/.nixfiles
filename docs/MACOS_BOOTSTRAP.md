# macOS Bootstrap and First Activation

The official multi-user Nix installer is installed on this MDM-managed Mac. Nix 2.34.7 and its
daemon are running, but nix-darwin has not been activated.

The active host follows the one-item-at-a-time process in `docs/MACOS_MIGRATION.md`. The first
generation adopts only nix-darwin, Home Manager, and the existing repository Brave module.
Homebrew, shell configuration, Git configuration, macOS defaults, and every other application
remain unchanged.

## SOPS Prerequisite

The Darwin generation decrypts shared MCP credentials during activation. An SSH agent can sign
with its key but cannot provide private-key material to `ssh-to-age`. Before the first build,
explicitly export the Bitwarden-managed Ed25519 private key to a protected temporary file, then
derive the same age key used on Linux:

```bash
mkdir -p "$HOME/.config/sops/age"
nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt"
chmod 600 "$HOME/.config/sops/age/keys.txt"
age-keygen -y "$HOME/.config/sops/age/keys.txt"
```

The printed public recipient must match `.sops.yaml`. Securely delete the exported SSH key once
the age identity has been derived. If exporting the SSH key is not possible, securely transfer the
existing `~/.config/sops/age/keys.txt` from Linux, or add a Mac-specific age recipient to
`.sops.yaml` and run `sops updatekeys secrets/github-token.yaml`. Do not begin activation while
`~/.config/sops/age/keys.txt` is missing.

## Build Without Activating

The installer has not enabled flakes globally yet, so pass the feature flag until the first switch:

```bash
nix --extra-experimental-features "nix-command flakes" \
  flake check --all-systems --no-build

nix --extra-experimental-features "nix-command flakes" \
  build .#darwinConfigurations.macbook-pro.system \
  --out-link /tmp/nixfiles-darwin-system
```

Both commands must pass before switching. The build is safe: it realizes the complete generation
in `/nix/store` without activating it.

Run nix-darwin's root-only compatibility check. It validates system activation preconditions but
does not switch generations:

```bash
sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  check --flake .#macbook-pro
```

## First Activation

Use the `darwin-rebuild` from the already-built, flake-pinned generation for the first activation:

```bash
sudo /tmp/nixfiles-darwin-system/sw/bin/darwin-rebuild \
  switch --flake .#macbook-pro
```

Subsequent activations use the installed command:

```bash
sudo darwin-rebuild switch --flake .#macbook-pro
```

macOS may request App Management permission when Home Manager exposes the Nix-provided Brave
application under `~/Applications/Home Manager Apps`.

## First-Activation Checks

Run the Activation 0 checklist in `docs/MACOS_MIGRATION.md`. Do not uninstall Homebrew Brave or add
another application until those checks and a reboot pass.

## Rollback

List and activate an earlier nix-darwin generation:

```bash
darwin-rebuild --list-generations
sudo /run/current-system/sw/bin/darwin-rebuild --rollback
```

The nix-darwin uninstaller is documented upstream:

- <https://github.com/nix-darwin/nix-darwin#uninstalling>

Do not remove Nix immediately after a failed activation without first restoring or uninstalling
nix-darwin; removing one ownership layer while the other remains can leave launchd configuration
inconsistent.
