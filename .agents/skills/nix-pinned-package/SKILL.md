---
name: nix-pinned-package
description: Install and maintain pinned Nix packages from fixed upstream versions through the shared packageUpdater and update-pins runner.
metadata:
  workflow: nix-update
  scope: repo
---

# Pinned Package Workflow

## Use This Skill

Use this when adding, changing, or debugging a package under `packages/` that is pinned to an
upstream version (release binary, tarball, AppImage, npm or PyPI artifact, branch snapshot), or
when its update fails. `docs/UPDATE_COMMANDS.md` is the full reference; read its
"Conventions for Pinned Packages" section first.

## Decision Tree

1. Prefer an existing nixpkgs package.
2. Otherwise write the smallest reproducible derivation in `packages/<name>/default.nix`
   (`finalAttrs` pattern) and expose it in `modules/packages.nix` with
   `packageUpdater = packageUpdater;`.
3. Give it `passthru.updateScript = packageUpdater.script { attr; file = ./default.nix; ... }`
   with the smallest knob that works:
   - `nixUpdateArgs` when nix-update can find the version (GitHub releases/tags, npm, PyPI,
     crates, `--version=branch=<name>`, `--version=unstable`, `--version-regex=...`);
   - `latestVersion` when it cannot: one shell command printing the version (`curl`, `jq`,
     `sed`, `github-api <path>` are available; avoid `head`/`grep -m1` under `pipefail`);
   - `postUpdate` only for artifacts coupled to the release that nix-update cannot see.
4. If the package cannot be automated, add a hold with a how-to reason to
   `scripts/update-pins.json` instead of an update script.

## Package Shape

- Keep the version as one string literal and every hash as a literal in the `file` passed to
  `packageUpdater.script`; derive URLs and asset names from the version.
- Multi-platform: keep per-system data in a plain `artifacts` set, build `passthru.sources`
  with `lib.mapAttrs` over it, and set `src = finalAttrs.passthru.sources.${system}`. Put
  other version-following fetches (skills at the tag, npm tarballs) in `passthru.sources`
  too. The updater re-hashes all of them from one host.
- Avoid burying package logic inside a NixOS or Home Manager module. A module that calls the
  package file directly passes
  `packageUpdater = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.package-updater;`.

## Guardrails

- Never add `update.ts`, a shell updater, or regex rewrites of `.nix` files.
- Never hand-edit hashes; run the updater.
- Do not use imperative installs like `npm -g`.
- Unfree packages exported through `flake.packages` must use an unfree-enabled `pkgs`
  (`unfreePkgs` in `modules/packages.nix`).

## Verification

```bash
nix run .#update-pins -- --check              # convention drift
nix run .#update-pins -- --only <name>        # exercise the update path
nix build .#<name> --no-link
```

To prove a new update path end to end, lower the version and corrupt the hashes in a scratch
copy, run the update, and confirm the original values come back.
