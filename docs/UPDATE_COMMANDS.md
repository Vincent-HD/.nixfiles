# Pinned Package Update Reference

Quick-reference commands for updating packages that are pinned to fixed upstream versions and backed by `fetchurl` / `fetchFromGitHub` sources.

## Data-Driven Update Runner

Routine updates are configured in `scripts/update-pins.json` and run through the Bun-based app:

```bash
nix run .#update-pins
```

Useful variants:

```bash
nix run .#update-pins -- --dry-run
nix run .#update-pins -- --only codex,curseforge
nix run .#update-pins -- --skip codex-desktop-linux
nix run .#update-pins -- --validate fast
nix run .#update-pins -- --list
```

`noctalia` is listed in the JSON denylist, so the default update flow skips it explicitly.

## nix-update Compatible Packages

These packages use the `finalAttrs` pattern and are wired so `nix-update` can bump versions and hashes automatically.

### codex

- **File**: `packages/codex/default.nix`
- **Pattern**: `stdenv.mkDerivation` + `fetchurl` from GitHub releases
- **Flake output**: `.#codex`
- **Note**: The release tag is `rust-v<version>`, so keep `version` as the bare semver.

```bash
nix run github:Mic92/nix-update -- --flake codex --use-github-releases --version-regex 'rust-v(.*)'
```

### lightjj

- **File**: `packages/lightjj/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + `fetchurl` from GitHub releases
- **Flake output**: `.#lightjj`

```bash
nix run github:Mic92/nix-update -- --flake lightjj
```

### jj-ryu

- **File**: `packages/jj-ryu/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + platform-selected `fetchurl` from GitHub releases
- **Flake output**: `.#jj-ryu`

```bash
nix run github:Mic92/nix-update -- --flake jj-ryu
```

If nix-update refuses the latest alpha release as unstable, use:

```bash
nix run github:Mic92/nix-update -- --flake jj-ryu --version=unstable
```

### curseforge

- **File**: `packages/curseforge/default.nix`
- **Pattern**: `appimageTools.wrapType2` + `fetchurl` from CurseForge's versioned AppImage URL
- **Flake output**: `.#curseforge`
- **Note**: Upstream artifact names include both the public version and a separate build number; use the package update script so both are updated together.

```bash
nix run github:Mic92/nix-update -- --flake curseforge --use-update-script
```

To run the package-specific updater directly:

```bash
nix run .#update-curseforge -- --check
```

## Branch-Pinned Packages

These packages are packaged in a `nix-update`-friendly shape, but the upstream tracking model means the naive command is not necessarily correct.

### crosspipe

- **File**: `packages/crosspipe/default.nix`
- **Why**: It is pinned to a specific commit on `pinpox/Crosspipe`, not an upstream release.
- **Risk**: `nix-update --version branch` follows the default branch head, which may be older or different from the custom commit you intentionally pinned.
- **How**: Only update after checking the exact target commit/branch manually, then prefetch the new source hash.

```bash
git ls-remote https://github.com/pinpox/Crosspipe.git
nix-prefetch-git https://github.com/pinpox/Crosspipe.git --rev <rev>
```

## Custom Flake Inputs

These are updated with `nix flake lock`, not `nix-update`.

### codex-desktop-linux

- **File**: `flake.nix`
- **Why**: It is a flake input that follows upstream `main`; `flake.lock` carries the reproducible revision.
- **How**: Refresh only this input in `flake.lock`.

```bash
nix flake update codex-desktop-linux
```

### noctalia

- **File**: `flake.nix`
- **Why**: It is intentionally pinned to a specific v4 revision and should stay out of routine updates until you migrate to v5.
- **How**: Do not update this as part of normal maintenance.

## One-Shot: Update All Straightforward Compatible Packages

Prefer the data-driven runner:

```bash
nix run .#update-pins -- --validate fast
```

## Verification

After any update, verify the package still builds:

```bash
nix build .#<package-name>
```

```bash
nix build .#jj-ryu
```

Then apply the system configuration:

```bash
sudo nixos-rebuild switch --flake .#pc-fixe
```
