# Pinned Package Update Reference

Quick-reference commands for updating packages that are pinned to fixed upstream versions and backed by `fetchurl` / `fetchFromGitHub` sources.

## nix-update Compatible Packages

These packages use the `finalAttrs` pattern and are wired so `nix-update` can bump versions and hashes automatically.

### codex

- **File**: `packages/codex/default.nix`
- **Pattern**: `stdenv.mkDerivation` + `fetchurl` from GitHub releases
- **Flake output**: `.#codex`
- **Note**: The release tag is `rust-v<version>`, so keep `version` as the bare semver.

```bash
nix run github:Mic92/nix-update -- --flake codex --use-github-releases
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

### sunshine-darwin

- **File**: `packages/sunshine-darwin/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + `fetchurl` from the official GitHub release DMG
- **Flake output**: `.#sunshine-darwin`

```bash
nix run github:Mic92/nix-update -- --flake sunshine-darwin
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

## Manual-Update Packages (Not nix-update Compatible)

These packages are pinned but cannot be updated with `nix-update` without refactoring.

### curseforge

- **File**: `modules/curseforge.nix`
- **Why**: Version is a plain `let` binding, not `finalAttrs.version`; uses `appimageTools.wrapType2`.
- **How**: Hand-edit `version` and `build`, then prefetch the new AppImage hash.

```bash
nix store prefetch-file https://curseforge.overwolf.com/electron/linux/CurseForge-<version>-<build>.AppImage
```

### nvidia-vaapi-driver (PR override)

- **File**: `modules/graphics.nix`
- **Why**: It is an `overrideAttrs` on an existing nixpkgs package inside an overlay, not a standalone derivation.
- **How**: Hand-edit `version`, `rev`, and `sha256`. Intended as a temporary override until the PR lands upstream.

## Custom Flake Inputs

These are updated with `nix flake lock`, not `nix-update`.

### codex-desktop-linux

- **File**: `flake.nix`
- **Why**: It is a flake input pinned to a Git commit.

```bash
nix flake lock --update-input codex-desktop-linux
```

### noctalia

- **File**: `flake.nix`
- **Why**: It is intentionally pinned to a specific v4 revision and should stay out of routine updates until you migrate to v5.
- **How**: Do not update this as part of normal maintenance.

## One-Shot: Update All Straightforward Compatible Packages

Run each `nix-update` command in sequence (or in separate terminals):

```bash
nix run github:Mic92/nix-update -- --flake codex --use-github-releases
nix run github:Mic92/nix-update -- --flake lightjj
nix run github:Mic92/nix-update -- --flake jj-ryu
nix run github:Mic92/nix-update -- --flake sunshine-darwin
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
