# Pinned Package Update Reference

Quick-reference commands for updating packages that are pinned to fixed upstream versions and backed by `fetchurl` / `fetchFromGitHub` sources.

## nix-update Compatible Packages

These packages use the `finalAttrs` pattern and are wired so `nix-update` can bump versions and hashes automatically.

### lightjj

- **File**: `packages/lightjj/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + `fetchurl` from GitHub releases
- **Flake output**: `.#lightjj`

```bash
nix run github:Mic92/nix-update -- --flake lightjj
```

### crosspipe

- **File**: `packages/crosspipe/default.nix`
- **Pattern**: `stdenv.mkDerivation` + `fetchFromGitHub`
- **Flake output**: `.#crosspipe`

```bash
nix run github:Mic92/nix-update -- --flake crosspipe
```

### jj-ryu

- **File**: `modules/coding/default.nix` (embedded, not a standalone flake package)
- **Pattern**: `stdenvNoCC.mkDerivation` + `fetchurl` from npm registry
- **Requires explicit `--version`** because there is no upstream Git tag to auto-detect.

```bash
nix run github:Mic92/nix-update -- --file modules/coding/default.nix --version <new-version> jj-ryu
```

Example:

```bash
nix run github:Mic92/nix-update -- --file modules/coding/default.nix --version 0.0.1-alpha.12 jj-ryu
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

## One-Shot: Update All Compatible Packages

Run each `nix-update` command in sequence (or in separate terminals):

```bash
nix run github:Mic92/nix-update -- --flake lightjj
nix run github:Mic92/nix-update -- --flake crosspipe
```

For `jj-ryu`, check <https://www.npmjs.com/package/jj-ryu-linux-x64> for the latest version first, then:

```bash
nix run github:Mic92/nix-update -- --file modules/coding/default.nix --version <version> jj-ryu
```

## Verification

After any update, verify the package still builds:

```bash
nix build .#<package-name>
```

Or for `jj-ryu` (which has no flake output):

```bash
nix eval '.#nixosConfigurations.pc-fixe.config.home-manager.users.vincent.home.packages' --apply 'pkgs: builtins.head (builtins.filter (p: (p.pname or "") == "jj-ryu") pkgs)'
```

Then apply the system configuration:

```bash
sudo nixos-rebuild switch --flake .#pc-fixe
```
