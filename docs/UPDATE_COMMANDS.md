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

Each package's `updateScript` (with a comment above it when the version source is unusual) is
the reference for how it updates; `nix run .#update-pins -- --list` shows what is held and why.
To test an update path, lower the version and corrupt the hashes in a scratch copy, then run:

```bash
nix run .#update-pins -- --only <package>
```

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
- **Before switching**: close T3 and back up `~/.t3`; restore that backup with the previous
  package when rolling back. Both hosts install `.#z-code` (it replaces the upstream `t3code`
  package), and its wrapper disables in-app updates.

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
- **Claude Code** comes from `nixpkgs`; it advances with that input, not through a pin here.

## vtask Local Releases

`vtask` is authored in this repository, rather than pinned to an upstream
release, so it is held in `scripts/update-pins.json`. Release it by hand; routine pin updates
never bump its SemVer version or rebuild its Git LFS binaries.

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
