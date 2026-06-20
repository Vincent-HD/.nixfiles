---
name: noctalia
description: Update modules/noctalia/noctalia.nix for Noctalia v5 (TOML-based settings, no JSON migration).
compatibility: opencode
metadata:
  workflow: noctalia-v5
  scope: repo
---

# Noctalia v5 Workflow

Use this skill when the user asks to update the Noctalia module or migrate Noctalia configuration.

## Important: v5 is a fresh rewrite

- Noctalia v5 uses a TOML config format under `~/.config/noctalia/config.toml`.
- v4 JSON exports are **not migrated automatically**.
- The Home Manager option is `programs.noctalia`, not `programs.noctalia-shell`.
- The binary is `noctalia`, not `noctalia-shell`.
- The IPC command is `noctalia msg <command>`, not `noctalia-shell ipc ...`.
- The v5 plugin system is experimental and uses a different manifest format; do not carry over v4 plugins blindly.

## Reference sources

- Upstream v5 example config: `https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/example.toml`
- v5 docs: `https://docs.noctalia.dev/v5/configuration/`

## Workflow

1. Read the current `modules/noctalia/noctalia.nix`.
2. Reference the upstream v5 example config and docs for current option names.
3. Update `programs.noctalia.settings` with the desired v5 TOML-compatible attrset.
4. Prefer omitting values that match upstream defaults.
5. Verify the rendered attrset with:
   ```bash
   nix eval .#nixosConfigurations.pc-fixe.config.home-manager.users.vincent.programs.noctalia.settings --json
   ```

## Guardrails

- Do not reference `programs.noctalia-shell`; that option no longer exists.
- Do not compare against v4 JSON snapshots (`modules/noctalia/assets/settings-default.json` and `settings-widgets-default.json`); they are no longer authoritative.
- When v5 plugins are involved, treat them as experimental and confirm the exact plugin ID and IPC shape against the v5 docs.
