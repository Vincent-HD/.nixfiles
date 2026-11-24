# Updating Pins

Every flake input and every pinned package in `packages/` is updated by one command:

```bash
nix run .#update-pins
```

Pass options after `--`; without it, Nix parses them as its own flags.

```bash
nix run .#update-pins -- --list              # inputs, packages, holds, validation sets
nix run .#update-pins -- --check             # fail on update-convention drift
nix run .#update-pins -- --dry-run           # print the commands only
nix run .#update-pins -- --inputs            # every unheld flake input
nix run .#update-pins -- --packages          # every unheld flake package
nix run .#update-pins -- --only codex,t3code # named entries (combines with --inputs/--packages)
nix run .#update-pins -- --skip dankmail
nix run .#update-pins -- --jobs 8            # package updates in parallel (default 4)
nix run .#update-pins -- --validate fast     # linux + darwin eval after the updates
nix run .#update-pins -- --validate full     # build this host's system after the updates
```

From any directory, `nrs update [options]` runs the same command in `NH_FLAKE` (default
`~/.nixfiles`) with the options above, and `nrs update --switch` rebuilds this machine after
every update succeeded:

```bash
nrs update --switch        # update everything, then switch
nrs update --only codex    # any update-pins option
```

The runner does not build packages: each host validates its own configuration with
`--validate full` or a normal rebuild.

## How It Works

1. **Discovery.** Inputs come from the root of `flake.lock`. Packages come from
   `packages.<current system>`, so Linux-only packages are updated from a Linux host.
2. **Selection.** An entry is skipped when it is listed under `holds` in
   `scripts/update-pins.json` (with its reason), or when it is an input whose URL in
   `flake.nix` names an exact commit (`pinned`: `nix flake update` cannot move it).
3. **Inputs first.** All selected inputs are refreshed in one `nix flake update`.
4. **Packages.** Each package's `passthru.updateScript` runs, several at a time, with its
   output in a per-package log. Every script is built by `packageUpdater.script`
   (`packages/package-updater`), which:
   - runs `nix-update` on the package (version detection, the running system's `src`
     hash, and dependency hashes such as `npmDepsHash`, `vendorHash`, or `cargoHash`);
   - when the version changed, prefetches every other fetch in `passthru.sources` and
     replaces its old hash by value in the package file, so all platforms are refreshed
     from one host without evaluating other systems;
   - finally runs the package's `postUpdate` hook, if any.
5. **Drift check.** Before anything runs, every package must use `packageUpdater.script`
   or have a hold, and every hold must name an existing input or package. `--check` runs
   only this check; the `update-pins-tests` flake check covers the runner itself.

`nix-update` itself is the `nix-update` flake input (upstream), so it is updated like any
other input.

## Conventions for Pinned Packages

Follow these rules for every package under `packages/`; the drift check enforces the
first two.

1. **Always declare an update path.** Set `passthru.updateScript = packageUpdater.script { ... }`.
   A package that truly cannot be automated (vendored source, local project) gets a hold in
   `scripts/update-pins.json` whose reason says how to update it by hand.
2. **Never write a per-package updater script.** Do not add `update.ts`, shell updaters, or
   anything that rewrites `.nix` files with regular expressions. Express the package with
   the knobs below instead.
3. **Pick the smallest knob that works**, in this order:
   - `nixUpdateArgs`: nix-update finds the version itself (GitHub releases or tags, npm,
     PyPI, crates, branch snapshots). Typical flags: `--use-github-releases`,
     `--version=unstable` (prereleases), `--version-regex=...`, `--version=branch=<name>`.
   - `latestVersion`: a shell command printing the target version, for sources nix-update
     cannot read (vendor APIs, install scripts, HTML indexes). It runs with `curl`, `jq`,
     `sed`, `grep`, and `github-api <path>` (authenticated GitHub REST) on `PATH`. Avoid
     `head`/`grep -m1` in pipelines (SIGPIPE fails `pipefail`); use `sed -n 1p`.
   - `postUpdate`: a short Bun script for artifacts coupled to the release that nix-update
     cannot see (a matching flake input, a generated lockfile). It receives
     `NIXFILES_ROOT`, `UPDATE_ATTR`, `UPDATE_FILE`, `UPDATE_OLD_VERSION`, and
     `UPDATE_NEW_VERSION`, and only runs after a version change.
4. **Put every version-following fetch in `passthru.sources`.** Multi-platform packages keep
   their per-system data (asset name, hash) in a plain `artifacts` attribute set, build
   `passthru.sources` with `lib.mapAttrs` over it, and select `src` from it. Secondary
   fetches that follow the version (skills at the same tag, an npm tarball) go in the same
   attribute set under a descriptive name. Keep every hash literal in the file passed as
   `file`.
5. **Keep the version a single string literal in `file`**, and derive every URL and asset
   name from it. If upstream names differ from the tag, derive them (for example
   `lib.versions.pad 3 version`) rather than storing a second version.
6. **Hold, don't disable.** Use a hold with a precise reason for anything intentionally
   frozen. Remove the hold when the reason no longer applies.

Minimal multi-platform example:

```nix
{ lib, stdenvNoCC, fetchurl, packageUpdater }:
let
  # Release artifact name and hash for each supported platform.
  artifacts = {
    "x86_64-linux" = { name = "tool-linux-x64"; hash = "sha256-..."; };
    "aarch64-darwin" = { name = "tool-darwin-arm64"; hash = "sha256-..."; };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tool";
  version = "1.2.3";
  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};
  # ...
  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://github.com/owner/tool/releases/download/v${finalAttrs.version}/${artifact.name}";
        hash = artifact.hash;
      }
    ) artifacts;
    updateScript = packageUpdater.script {
      attr = "tool";
      file = ./default.nix;
      nixUpdateArgs = [ "--use-github-releases" ];
    };
  };
  meta.platforms = builtins.attrNames artifacts;
})
```

Wire the package in `modules/packages.nix` with `packageUpdater = packageUpdater;`. A module
that calls the package file directly passes
`packageUpdater = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.package-updater;`
(it is only used by `passthru.updateScript`).

To test an update path, check out a throwaway copy, lower the version and corrupt the
hashes, then run the package's update script:

```bash
nix run .#update-pins -- --only <package>
```

## Package Reference

| Package | Version source | Notes |
| --- | --- | --- |
| `agent-browser` | GitHub releases | 3 platforms |
| `arch-ops-server` | PyPI JSON (`latestVersion`) | universal wheel |
| `codeburn` | npm `latest` (`latestVersion`) | tag source + npm artifact; nix-update refreshes `npmDepsHash` |
| `codex` | GitHub API, 30 releases (`latestVersion`) | nix-update's 100-release page times out on `openai/codex` |
| `craft-apps` (`pdfcraft`, `photocraft`, `wordcraft`) | GitHub releases | one pin file per app in `packages/craft-apps/apps/` |
| `crosspipe` | `main` branch snapshot | |
| `curseforge` | Electron feed `latest-linux.yml` (`latestVersion`) | version is `<version>-<build>` |
| `cursor-agent` | install script (`latestVersion`) | 4 platforms |
| `dankmail` | GitHub releases | upstream renamed to Dux Mail; binary and service keep `dmail` |
| `dms-prebuilt` | GitHub releases | `postUpdate` moves the held `dms` input to the release commit |
| `droidcam-client` | GitHub releases `droidcam-<version>` | |
| `equicord-prebuilt` | GitHub releases (date tags) | |
| `executor` | npm `latest` (`latestVersion`) | 4 platforms, suffixed npm versions |
| `gamescope-lanczos` | fork `master` snapshot | recursive submodules; build and test the WSI variants after updating |
| `handy` | GitHub releases | |
| `jj-ryu` | GitHub prereleases | alpha-only upstream |
| `lightjj` | GitHub releases | |
| `lsfg-vk` | build index "Latest release" (`latestVersion`) | |
| `open-pencil` | GitHub releases | `postUpdate` regenerates the `open-pencil-mcp` lockfile and hash |
| `opencodev2` | OpenCode update API (`latestVersion`) | |
| `plannotator` | GitHub releases | binaries + shared skills at the same tag |
| `portless` | npm `latest` (`latestVersion`) | |
| `t3code` | GitHub nightly prereleases | Linux AppImage name is unversioned; the tag path pins it |
| `wifi-audio-streaming` | GitHub releases | tags drop the patch number; assets pad it |

## Holds and Manual Updates

The current holds and their reasons are listed by `nix run .#update-pins -- --list`.

### Commit-pinned inputs

`noctalia` (intentional v4 hold until the v5 migration), `dms-plugins`, `quick-capture`, and
`screen-capture-toolbar` name a reviewed commit in `flake.nix`. To update one, review the
upstream change, edit the revision in `flake.nix`, then refresh only that entry:

```bash
nix flake update <input>
```

### z-code

- **File**: `flake.nix` (`z-code` input) and `flake.lock`
- **Flake packages**: `.#z-code-source` (pinned source snapshot) and `.#z-code`
- **Source**: [Vincent-HD/zcode](https://github.com/Vincent-HD/zcode), branch `z-code`
- **Update**: choose and review an exact fork commit, edit the URL in `flake.nix` to
  `github:Vincent-HD/zcode/<reviewed-commit>`, run `nix flake update z-code`, check that the
  lock revision is exactly the reviewed commit, and build `.#z-code`. Never use a moving
  branch or tag for this input.

### herdr

The URL selects a release tag. Change the tag in `flake.nix`, then refresh the lock entry and
verify both host package sets:

```bash
nix flake update herdr
```

### dms

The `dms` input (QML and modules) must match the `dms-prebuilt` CLI release, so it is held and
only moved by the `dms-prebuilt` update. Its `postUpdate` hook resolves the release tag's
commit, refreshes the input into a candidate lock, and swaps it in only when the stable branch
is at that commit; otherwise the update fails and `flake.lock` is untouched. The package build
also refuses a mismatched pair.

```bash
nix run .#update-pins -- --only dms-prebuilt
```

### cpuid-fault-emulation

The source archive is attached to a forum post that blocks unattended downloads. Download and
inspect it manually, replace the vendored tree, then build and evaluate the Linux host:

```bash
rm -rf packages/cpuid-fault-emulation/source
nix shell nixpkgs#unzip -c unzip <verified-local-archive> -d packages/cpuid-fault-emulation/source
nix build .#cpuid-fault-emulation
nix eval .#nixosConfigurations.pc-fixe.config.system.build.toplevel.drvPath --raw
```

## Input Notes

- **nix-cachyos-kernel**: keep the input on the `release` branch and do not make its nixpkgs
  follow this repository; upstream pins its own nixpkgs for binary-cache hits. After an update,
  check the default and `stock` kernels and that the NVIDIA and CPUID modules follow them:

  ```bash
  nix eval --raw '.#nixosConfigurations.pc-fixe.config.boot.kernelPackages.kernel.name'
  nix eval --raw '.#nixosConfigurations.pc-fixe.config.specialisation.stock.configuration.boot.kernelPackages.kernel.name'
  ```

- **nix-gaming**: only the standalone `platformOptimizations` module is imported; review it
  against the current Steam/NixOS options.
- **Skill inputs** (`context7-skills`, `mattpocock-skills`, `humanlayer-skills`,
  `kitlangton-skills`): review the upstream skill changes before applying Home Manager.
- **Claude Code** follows `nixpkgs`; update that input when its packaged version advances.

## Z Code Integration

The Z Code integration targets x86_64 Linux and Apple Silicon macOS and is pinned to reviewed fork
commit `7a90eb01528d93bfd2d2a183147a25a0bc66e3bb` on branch `z-code`, based on upstream
`v0.1.9-nightly.20261110.4478`. Both hosts install that package. Build it with
`nix build .#z-code --no-link`. The Home Manager module selects the same output
and uses nixfiles' pinned package set. The `z-code-source` and `z-code` outputs resolve from
the locked GitHub input and do not depend on a local checkout.

The Home Manager wrapper routes all three executable names (`t3code`, `zcode`, and `z-code`)
through the same managed launcher, including its provider `PATH` and the
`T3CODE_DISABLE_AUTO_UPDATE=true` setting. On Linux, the desktop icon comes from the fork package's
extracted AppImage. The desktop entry remains `t3code` and keeps the `t3code` URL schemes and
window class to preserve the existing T3 profile and session identity. On macOS, the fork repacks the
upstream arm64 zip and re-signs it ad hoc, so the bundle no longer carries the upstream Developer ID
signature.

## T3 Code and Provider CLIs

T3 Code tracks GitHub nightly prereleases. Linux installs the pinned Z Code fork instead of the
`t3code` package; macOS keeps the signed upstream bundle. `modules/agents/t3code.nix` disables
upstream auto-updates, so the update runner and the next rebuild own nightly upgrades. Close T3
and back up `~/.t3` before upgrading persistent state; restore that backup with the old package
when rolling back.

Provider CLIs are managed separately from the T3 application. The Home Manager
module pins the Codex, Claude, Cursor, and OpenCode executable paths explicitly;
both Linux Codex accounts use the same package. Rebuild and fully restart T3
after updating them. Existing sessions can keep their already-running CLI.
T3's **Update all** cannot update immutable Nix store packages: use the Codex,
Cursor Agent, and OpenCode commands in this document. Claude Code follows
`nixpkgs`; update that input when its packaged version advances.

Investigation on 2026-10-23 found Perso configured for Codex 0.163.0 while Evvi
inherited 0.162.1 through executable discovery. Cursor was pinned to
2026.10.22-27dcf5f in this repo but the running environment still resolved
2026.10.14-941492e. Codex was refreshed to 0.164.0 and OpenCode to 2.1.4.
Claude's upstream npm release was 2.1.309, while both the locked nixpkgs and
the current `nixos-unstable` manifest still provided 2.1.303. Updating nixpkgs
alone would therefore not close that gap yet; prefer waiting for its package
update over adding another installation method.

Perso uses `~/.codex`; Evvi uses `~/.codex-evvi`, which had no user
`config.toml`. These are independent state directories, including authentication,
plugins, and user settings. OpenCodex has been removed. T3 still passes explicit
launch arguments that set `model_provider` to `openai` and `openai_base_url` to
`https://chatgpt.com/backend-api/codex` for both accounts, so a leftover local
proxy setting cannot redirect subscription traffic. Standalone Codex uses the
same direct ChatGPT endpoint. T3 forwards these configuration arguments to both
app-server and auxiliary exec launches. Leave `T3CODE_CODEX_LAUNCH_ARGS` unset:
T3 gives that environment variable precedence over per-account launch arguments.
The grey `~/.codex-t3/personal` text in the settings form is a placeholder, not
an active shadow home.

Keep separate homes to preserve the current account separation. If shared
settings are desired, preserve the T3 direct-connection overrides.
For a few shared preferences, manage just those preferences in each home's
config. For shared state as well, T3 supports a common `homePath` and a distinct
`shadowHomePath` per account, with separate `auth.json` files. Migrate with T3
closed and backups of both homes: Evvi already contains real state directories
that conflict with the symlinks T3 creates for a shadow home. Do not simply
point its shadow home at the existing directory or copy Perso's credentials.

## vtask Local Releases

`vtask` is authored in this repository, rather than pinned to an upstream
release. It is held in `scripts/update-pins.json`; the steps below rebuild the
Git LFS binaries; routine upstream pin updates do not bump its SemVer version.

```bash
nix develop .#vtask
pnpm --dir packages/vtask install --frozen-lockfile
pnpm --dir packages/vtask version patch --no-git-tag-version
pnpm --dir packages/vtask release
VTASK_BINARY="$PWD/packages/vtask/bin/x86_64-linux/vtask" pnpm --dir packages/vtask test
nix build .#vtask
git add packages/vtask/package.json packages/vtask/pnpm-lock.yaml packages/vtask/bin
```

Use `minor` for features and `major` for breaking changes once the interface
is stable. `pnpm release` cross-compiles both configured platforms with the
Nix-pinned Bun compiler and records source fingerprints, checksums and sizes.
Run native checks on macOS before publishing a Darwin release. Nix only
packages these checked-in binaries and never compiles vtask: a release whose
fingerprint no longer matches the sources fails evaluation and asks for
`pnpm release`, and an unhydrated LFS pointer asks for `git lfs pull`. Neither
ordinary switches nor `nix run .#vtask` mutate the repository's release files.

The executable is installed by the shared Home Manager command-line module,
and `programs.git.lfs.enable` provides clone-time hydration on both hosts.
Publishing a revision containing LFS pointers must also upload its LFS objects;
that happens on a normal Git push with the installed LFS hook.
