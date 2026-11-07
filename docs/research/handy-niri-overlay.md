# Handy recording overlay rendering on Niri with NVIDIA

Research date: 2026-11-05

## Finding

The screenshot’s black, see-through rectangle with only the pink recording indicator clearly drawn closely matches Handy upstream issue [#2166](https://github.com/cjpais/Handy/issues/2166): a small square around the pink dot remains visible while the rest of the overlay becomes transparent or flickers. The issue is specific to Handy’s Linux WebKitGTK rendering path on WebKitGTK 2.54, rather than evidence that NVIDIA transcription acceleration or Niri’s general transparency setting is broken.

The upstream investigation found that WebKitGTK 2.54 repaints only damaged portions of each frame. Handy 0.9.8 disables WebKit’s DMA-BUF renderer to avoid GPU/display-server crashes; on WebKitGTK 2.54 that path leaves undamaged portions of the overlay transparent. Issue reports include Niri and NVIDIA systems, and the upstream fix was tested on NixOS + Niri + WebKitGTK 2.54.1 + NVIDIA. This is a strong match for the supplied screenshot and host description, though the screenshot alone cannot establish which GTK backend the running Handy process selected.

## Repository state

- [`modules/handy.nix`](../../modules/handy.nix) installs `pkgs.handy` and `pkgs.wtype` on Linux.
- [`flake.lock`](../../flake.lock) pins nixpkgs at `31ecbaca1bdefa45dffc409f0250bd8039ea0010` (`nixos-unstable`). Evaluation of this checkout returns Handy **0.9.8** and `webkitgtk_4_1` **2.54.1**.
- The pinned Nixpkgs package recipe is [`pkgs/by-name/ha/handy/package.nix`](https://github.com/NixOS/nixpkgs/blob/31ecbaca1bdefa45dffc409f0250bd8039ea0010/pkgs/by-name/ha/handy/package.nix). It wraps Handy with `WEBKIT_DISABLE_DMABUF_RENDERER=1`. The [Handy v0.9.8 entry point](https://github.com/cjpais/Handy/blob/v0.9.8/src-tauri/src/main.rs) also sets that value unconditionally. Thus setting `WEBKIT_DISABLE_DMABUF_RENDERER=0` in the shell does not override the current package behavior.
- [`modules/niri.nix`](../../modules/niri.nix) already sets `prefer-no-csd = true` and disables the focus ring. The general layout border remains enabled. No Handy-specific Niri window rule is currently defined.
- The host’s Handy model GPU and overlay GPU are separate paths: Handy uses Vulkan for model inference, while the recording UI is a GTK/WebKitGTK view. Changing inference-device selection or global NVIDIA rendering settings is not supported by this symptom.

## Recommended fix

**Update Handy to v0.10.0 or later containing [PR #2360](https://github.com/cjpais/Handy/pull/2360).** Handy released v0.10.0 on November 2, 2026, and the release notes include this overlay fix. The fix selects the renderer based on the linked WebKitGTK version: on 2.54 and later, it keeps the compositor enabled and forces the swap chain onto shared memory with `WEBKIT_DMABUF_RENDERER_FORCE_SHM=1`; on older WebKitGTK it retains the old DMA-BUF-disabled behavior. It also preserves explicit user overrides and removes the Nix wrapper’s unconditional renderer pin. The fix restores full-frame painting without enabling DMA-BUF imports, avoiding the NVIDIA crash risk of simply turning the renderer back on. Shared memory can involve extra copies compared with direct GPU buffer imports, but this is the upstream-tested compatibility choice for WebKitGTK 2.54.

The upstream PR explicitly reports a test on **NixOS, Niri, Wayland, WebKitGTK 2.54.1, and NVIDIA**, with the full overlay stable through repeated record/stop cycles. This makes updating the package the most targeted, lowest-risk action for this setup.

## Practical options and tradeoffs

| Option | When to use it | Tradeoffs / limitations |
| --- | --- | --- |
| **Update to Handy 0.10.0+ with PR #2360** | Preferred permanent fix for this repo’s Handy 0.9.8 + WebKitGTK 2.54.1 combination. | Requires the pinned Nixpkgs Handy package to advance, or a local package override/backport. Uses the shared-memory swap chain on WebKitGTK 2.54+ instead of DMA-BUF imports. |
| **Disable the overlay in Handy settings** (`Settings → Advanced → Overlay Position → None`) | Immediate visual workaround while keeping transcription available. | Removes the visual recording indicator. Handy suggests audio feedback as an alternative. Its Linux docs also warn that an enabled overlay may take focus on some environments. See [Handy Advanced settings](https://handy.computer/docs/advanced) and [Troubleshooting](https://handy.computer/docs/troubleshooting). |
| **Backport Handy PR #2360 into a local Nix package override** | If waiting for the nixpkgs pin is undesirable. | Requires maintaining a package override/patch and ensuring the wrapper no longer hard-sets `WEBKIT_DISABLE_DMABUF_RENDERER=1`. Prefer the complete upstream change over a one-off environment tweak because it contains the WebKit-version selection and override behavior. |
| **Try `WEBKIT_DISABLE_DMABUF_RENDERER=0` only with code that honors the override** | A diagnostic/temporary workaround if PR #2360 is unavailable and the simpler #2249 override patch is applied. | It cannot take effect with this checkout’s current Handy 0.9.8 source and Nix wrapper. On one reported NVIDIA setup it caused a Wayland protocol error/crash until `__NV_DISABLE_EXPLICIT_SYNC=1` was added. That is a narrow report, not a general safe default; it trades the partial repaint for a different GPU/Wayland compatibility risk. See [Handy PR #2249](https://github.com/cjpais/Handy/pull/2249) and [issue #2166’s NVIDIA report](https://github.com/cjpais/Handy/issues/2166). |
| **Test `HANDY_NO_GTK_LAYER_SHELL=1` briefly** | Only if the overlay is missing, misplaced, or logs indicate a layer-shell problem. This disables GTK layer-shell initialization and is a useful A/B test of that subsystem. | It is not the fix for the WebKitGTK partial repaint. Handy falls back to a regular always-on-top window; on Wayland the client cannot choose its position, and the fallback can appear centered or take focus. Do not make it permanent unless it fixes a distinct layer-shell failure. See [Handy’s Linux startup troubleshooting](https://github.com/cjpais/Handy#linux-startup-crashes-or-instability). |
| **Niri border/transparency rule, only if a compositor tint remains after the renderer fix** | If the complete Handy pill paints but a stable rectangular tint/border is still visible through it. | Niri documents that borders/focus-ring backing can show through semitransparent windows. Its FAQ recommends `prefer-no-csd` or a targeted `draw-border-with-background` rule. This config already has `prefer-no-csd = true` and focus ring off, making that less likely than the WebKitGTK bug. A rule applies only if Handy appears to Niri as a normal window; it will not fix damaged WebKit content on a layer-shell surface. See [Niri FAQ](https://github.com/niri-wm/niri/blob/main/docs/wiki/FAQ.md) and [window-rule reference](https://github.com/niri-wm/niri/blob/main/docs/wiki/Configuration%3A-Window-Rules.md). |

## Suggested verification sequence

1. Confirm the running app is the Nix package rather than an older AppImage or another Handy install; then confirm versions with:

   ```sh
   nix eval --raw '.#nixosConfigurations.pc-fixe.pkgs.handy.version'
   nix eval --raw '.#nixosConfigurations.pc-fixe.pkgs.webkitgtk_4_1.version'
   ```

2. On the current package, treat the 0.9.8/WebKitGTK 2.54.1 pairing as the likely cause. Do not expect `WEBKIT_DISABLE_DMABUF_RENDERER=0 handy` to override it: both Handy 0.9.8 and the current Nix wrapper force `1`.
3. Prefer moving the package to Handy 0.10.0+ containing #2360. If a temporary override is needed, use the full upstream renderer-selection fix rather than setting `WEBKIT_DISABLE_DMABUF_RENDERER=0` alone.
4. Compare the overlay over a uniform, bright background and through several record/stop cycles. Success means the entire rounded pill remains painted while the dot/waveform animates. If only a stable border/tint remains, then investigate a targeted Niri border rule. If the overlay instead disappears or is badly positioned, test layer-shell separately with `HANDY_NO_GTK_LAYER_SHELL=1` and expect fallback positioning/focus tradeoffs.

## Primary sources

- [Handy issue #2166: WebKitGTK 2.54 overlay partial repaint and NVIDIA findings](https://github.com/cjpais/Handy/issues/2166)
- [Handy PR #2360: fix transparent overlay painting on WebKitGTK 2.54](https://github.com/cjpais/Handy/pull/2360)
- [Handy v0.10.0 release notes](https://github.com/cjpais/Handy/releases/tag/v0.10.0)
- [Handy v0.9.8 Linux entry point](https://github.com/cjpais/Handy/blob/v0.9.8/src-tauri/src/main.rs)
- [Handy PR #2249: preserve explicit renderer overrides](https://github.com/cjpais/Handy/pull/2249)
- [Handy PR #1700: Wayland overlay restoration, manually verified on Niri](https://github.com/cjpais/Handy/pull/1700)
- [Handy troubleshooting](https://handy.computer/docs/troubleshooting) and [Advanced settings](https://handy.computer/docs/advanced)
- [Niri FAQ: semitransparent windows and compositor borders](https://github.com/niri-wm/niri/blob/main/docs/wiki/FAQ.md)
- [Niri window-rule reference](https://github.com/niri-wm/niri/blob/main/docs/wiki/Configuration%3A-Window-Rules.md)
