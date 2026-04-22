---
name: nix-pinned-package
description: Install and maintain pinned Nix packages from fixed upstream versions in a nix-update-friendly way.
compatibility: opencode
metadata:
  workflow: nix-update
  scope: repo
---

# Pinned Package Workflow

## Use This Skill

Use this when the user wants to install something declaratively, but it must stay pinned to a specific upstream version, tarball, AppImage, npm artifact, or similar fixed-output source.

## Default Decision Tree

1. Prefer an existing nixpkgs package.
2. If none exists, use the smallest reproducible fixed-output derivation.
3. Keep the package in a standalone file such as `packages/<name>.nix`.
4. Expose it as a flake package output if you want `nix-update --flake` to manage it.
5. Only fall back to a custom updater when `nix-update` cannot safely follow the version path.

## Package Shape

- Keep the derivation explicit: `pname`, `version`, source URL, hash, wrapper, and metadata.
- Avoid burying package logic inside a NixOS or Home Manager module.
- If a module needs the package, import the package file and read `passthru` fields from the package instead of duplicating version data.

## Updateability Rules

- Prefer `nix-update` over hand-editing hashes.
- If the source is versioned and machine-readable, add `passthru.updateScript`.
- The update script should fetch upstream release metadata, determine the new version, prefetch the fixed-output hash, and rewrite the package file.
- Keep the update script adjacent to the package definition.
- Use `nix-update --flake --use-update-script <name>` when the package is exposed as a flake output.

## Unfree Packages

- If the package is unfree and exported via `flake.packages`, make sure the flake `pkgs` instance allows unfree packages.
- Do not rely on the NixOS host config alone.

## Verification

Run:

- `nix build .#<name>`
- `nix run github:Mic92/nix-update -- --flake --use-update-script <name>`

## Guardrails

- Do not use imperative installs like `npm -g`.
- Do not create a one-off update script if `nix-update` can do the job cleanly.
- Ask a short clarification if the source cannot be pinned or updated safely.
