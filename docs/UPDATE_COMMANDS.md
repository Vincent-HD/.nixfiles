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

The `codex` and `curseforge` outputs are Linux-only. The data-driven updater
reads each entry's `systems` field and skips packages that do not support the
current host. Run their normal commands on a Linux target. Passing
`--system x86_64-linux` alone does not provide a Linux builder on
Darwin.

## nix-update Compatible Packages

These packages use the `finalAttrs` pattern and are wired so `nix-update` can bump versions and hashes automatically.

### codex

- **File**: `packages/codex/default.nix`
- **Pattern**: `stdenv.mkDerivation` + `fetchurl` from GitHub releases
- **Flake output**: `.#codex`
- **Note**: The release tag is `rust-v<version>`, so keep `version` as the bare semver. Fetch `codex-package-x86_64-unknown-linux-musl.tar.gz` (not the bare CLI tarball) so `codex-code-mode-host` is installed next to `codex`.
- **Release lookup**: Limit discovery to the newest 100 releases (one GitHub API page).

```bash
nix run github:Mic92/nix-update -- --flake codex --use-github-releases --github-releases-limit 100 --version-regex 'rust-v(.*)'
```

### lightjj

- **File**: `packages/lightjj/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + `fetchurl` from GitHub releases
- **Flake output**: `.#lightjj`

```bash
nix run github:Mic92/nix-update -- --flake lightjj
```

### opencodex

- **File**: `packages/opencodex/default.nix`
- **Pattern**: npm release tarball + tagged Bun lockfile + fixed-output Bun dependency closure
- **Flake output**: `.#opencodex`
- **Note**: The package runs with Nix's Bun runtime and discards OpenCodex's unused bundled npm Bun binary. Its update script refreshes the tarball, lockfile, and dependency-closure hashes together, including when only the Bun dependency closure changed.

```bash
nix run github:Mic92/nix-update -- --flake opencodex --use-update-script
```

### agent-browser

- **File**: `packages/agent-browser/default.nix`
- **Pattern**: platform-selected native GitHub release binaries
- **Flake output**: `.#agent-browser`

```bash
nix run github:Mic92/nix-update -- --flake agent-browser --use-update-script
```

### executor

- **File**: `packages/executor/default.nix`
- **Pattern**: platform-selected npm binary archives
- **Flake output**: `.#executor`
- **Note**: The updater reads npm's published integrity metadata only for the platform where it runs.

```bash
nix run github:Mic92/nix-update -- --flake executor --use-update-script
```

### arch-ops-server

- **File**: `packages/arch-ops-server/default.nix`
- **Pattern**: `python3Packages.buildPythonApplication` + universal PyPI wheel
- **Flake output**: `.#arch-ops-server`
- **Note**: The wheel avoids the sdist's strict, older `uv_build` constraint.

```bash
nix run github:Mic92/nix-update -- --flake arch-ops-server --use-update-script
```

### papercuts

- **File**: `packages/papercuts/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + `fetchFromGitHub` tagged source compiled with Bun
- **Flake output**: `.#papercuts`

```bash
nix run github:Mic92/nix-update -- --flake papercuts --use-github-releases
```

### portless

- **File**: `packages/portless/default.nix`
- **Pattern**: self-contained npm release tarball executed with Nix's Node.js 24 runtime
- **Flake output**: `.#portless`

```bash
nix run github:Mic92/nix-update -- --flake portless --use-update-script
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

### cursor-agent

- **File**: `packages/cursor-agent/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + Cursor's versioned multi-architecture archives
- **Flake output**: `.#cursor-agent`
- **Note**: Cursor publishes the current version through its installer. The package update script refreshes only the archive for the platform where it runs.

```bash
nix run github:Mic92/nix-update -- --flake cursor-agent --use-update-script
```

### t3code

- **File**: `packages/t3code/default.nix`
- **Pattern**: Linux AppImage via `appimageTools.wrapType2`; macOS DMG via `undmg`
- **Flake output**: `.#t3code`
- **Note**: This tracks GitHub nightly prereleases, not stable tags. The update script refreshes only the artifact for the platform where it runs.

```bash
nix run github:Mic92/nix-update -- --flake t3code --use-update-script
```

### plannotator

- **File**: `packages/plannotator/default.nix`
- **Pattern**: `stdenvNoCC.mkDerivation` + platform-selected release binary and tagged shared Agent Skills
- **Flake output**: `.#plannotator`
- **Note**: The update script refreshes the current platform's release checksum and the tagged source hash that supplies the Codex/Cursor-compatible skills.

```bash
nix run github:Mic92/nix-update -- --flake plannotator --use-update-script
```

### moonshine

- **File**: `packages/moonshine/default.nix`
- **Pattern**: `stdenv.mkDerivation` + `fetchurl` from the upstream Linux release archive
- **Flake output**: `.#moonshine`
- **Note**: This is intentionally the prebuilt `x86_64-linux` release; it avoids compiling Moonshine's Rust workspace.

```bash
nix run github:Mic92/nix-update -- --flake moonshine
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

### cpuid-fault-emulation

- **File**: `packages/cpuid-fault-emulation/default.nix`
- **Source**: locally vendored `source/` tree extracted from `cpuid_fault_emulation.zip`
- **Flake output**: `.#cpuid-fault-emulation`
- **Why**: the source archive is attached to a forum post that blocks unattended downloads, so it cannot be safely updated through `nix-update`.
- **How**: manually download, inspect, and replace the archive only after confirming the source and intended version. Then build the module and evaluate the Linux host before switching.

```bash
rm -rf packages/cpuid-fault-emulation/source
nix shell nixpkgs#unzip -c unzip <verified-local-archive> -d packages/cpuid-fault-emulation/source
nix build .#cpuid-fault-emulation
nix eval .#nixosConfigurations.pc-fixe.config.system.build.toplevel.drvPath --raw
```

## Custom Flake Inputs

These are updated with `nix flake lock`, not `nix-update`.

### spicetify-nix

- **File**: `flake.nix`
- **Why**: Provides the Home Manager module and pinned Spicetify apps/extensions used by the Spotify configuration.
- **How**: Refresh the locked source, then review compatibility with the current Spotify package before applying Home Manager.

```bash
nix flake update spicetify-nix
```

### nix-gaming

- **File**: `flake.nix`
- **Why**: Provides the standalone `platformOptimizations` NixOS module. The module is imported
  explicitly; nix-gaming's optional game, Wine, and Proton packages are not installed by this host.
- **How**: Refresh the locked source, then review the module against the current Steam/NixOS options.

```bash
nix flake update nix-gaming
```

### nix-cachyos-kernel

- **File**: `flake.nix`
- **Why**: Provides the release-branch CachyOS kernel package set used by the `cachyos` boot
  specialization in `modules/gaming-optimization.nix`.
- **Important**: Keep the input on the `release` branch and do not make its nixpkgs input follow this
  repository. The upstream project pins its own nixpkgs revision for binary-cache compatibility.
- **How**: Refresh the lock entry, then evaluate the `cachyos` specialization and check that the
  NVIDIA and custom CPUID modules still follow the selected kernel.

```bash
nix flake update nix-cachyos-kernel
nix eval --raw '.#nixosConfigurations.pc-fixe.config.specialisation.cachyos.configuration.boot.kernelPackages.kernel.name'
```

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

### context7-skills

- **File**: `flake.nix`
- **Why**: Provides only the selected upstream `context7-mcp` Agent Skill through Home Manager.
- **How**: Refresh the locked source, then review the upstream skill changes before applying Home Manager.

```bash
nix flake update context7-skills
```

### mattpocock-skills

- **File**: `flake.nix`
- **Why**: Provides the selected upstream `grill-me`, `handoff`, and `research` Agent Skills through Home Manager. `bro` is a local snapshot.
- **How**: Refresh the locked source, then review the upstream skill changes before applying Home Manager.

```bash
nix flake update mattpocock-skills
```

### humanlayer-skills

- **File**: `flake.nix`
- **Why**: Provides only the selected upstream `narrow-react-prop-types` Agent Skill through Home Manager.
- **How**: Refresh the locked source, then review the upstream skill changes before applying Home Manager.

```bash
nix flake update humanlayer-skills
```

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
