---
name: noctalia
description: Compare Noctalia JSON exports against local and upstream defaults before updating `modules/noctalia/noctalia.nix`.
compatibility: opencode
metadata:
  workflow: noctalia-json
  scope: repo
---

# Noctalia JSON Workflow

Use this skill when the user provides a Noctalia settings export or asks to update the Noctalia module.

## Default Sources

Check the local snapshots first:

- `modules/noctalia/assets/settings-default.json`
- `modules/noctalia/assets/settings-widgets-default.json`

Then confirm against upstream if needed:

- `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/Commons/Settings.qml`
- `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/Assets/settings-default.json`
- `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/Assets/settings-widgets-default.json`

## Workflow

1. Compare the pasted JSON against the local default snapshots.
2. Keep only values that differ from the defaults.
3. Update `modules/noctalia/noctalia.nix` with the non-default values.
4. Verify the rendered settings with `nix eval .#nixosConfigurations.pc-fixe.config.home-manager.users.vincent.programs.noctalia-shell.settings --json`.

## Guardrails

- Prefer omitting default values, even if they appear in the export.
- Treat the upstream JSON exports as full snapshots, not edited-only diffs.
- If upstream changes, refresh the two local default snapshot files before editing the module.
