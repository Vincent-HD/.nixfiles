# LACT RTX 3080 Ti implementation plan

## Goal

Recreate the proven parts of the MSI Afterburner Profile 1 on `pc-fixe` with LACT, while keeping rollback simple and avoiding competing GPU-control tools.

The GTA IV benchmark path is abandoned because it crashes on this installation. This plan therefore uses a fixed `vkmark` synthetic workload for the original low-resolution baseline and an off-screen `glmark2` workload at 3440x1440 for high-resolution validation. Synthetic results validate repeatable GPU throughput and stability; they do not predict in-game FPS.

The plan initially enables LACT without managed settings, so the real driver capabilities and safe values can be observed on this machine. The first V/F trial is applied through LACT's local Unix-socket API; Nixification remains gated on the measured result.

## Ground truth

| Item | Verified value |
| --- | --- |
| GPU | NVIDIA GeForce RTX 3080 Ti / GA102 (`10de:2208`) |
| PCI subsystem | NVIDIA (`10de:1535`) |
| Current BDF | `0000:2b:00.0` |
| LACT device ID | `10DE:2208-10DE:1535-0000:2b:00.0` |
| NVIDIA driver | `595.99.02` (`hardware.nvidia.open = true`) |
| Current/default power cap | 350 W |
| Driver-supported power-cap range | 100–400 W |
| MSI profile target | 1935 MHz at 900 mV, flat above 900 mV; +800 MHz memory; 114% power; 35% fixed fan |

The profile's 114% power target is `399 W` (`350 × 1.14`), inside the current 400 W driver limit. Treat 399 W as a later validation target, not the first setting to apply.

The Windows profile's GPU identity matches this card, but its old PCI location does not. LACT now reports the device ID above; use that LACT-generated identity for later declarative settings rather than copying the Windows BDF.

## Non-negotiable guardrails

1. LACT is the only process that controls clocks, power, and fans. Do not add CoreCtrl, GreenWithEnvy, `nvidia-settings` reapply scripts, or Coolbits alongside it.
2. Do not enter the extracted global `-300 MHz` core offset together with the custom V/F curve. The curve already incorporates that offset; combining them can double-apply it.
3. Start with NVIDIA's automatic fan control. The Windows fixed 35% fan setting is optional and should not be copied until temperatures, noise, and fan behavior under Linux are known.
4. Change one control at a time and test it before saving the next. LACT requires confirmation for tuning changes and normally reverts unconfirmed changes after five seconds.
5. Keep LACT's TCP listener disabled. Local Unix-socket access is sufficient.

## Phase 1 — enable LACT without tuning

Edit [`modules/graphics.nix`](../modules/graphics.nix) and add only:

```nix
services.lact.enable = true;
```

Do not set `services.lact.settings` yet. The NixOS module already installs the LACT package and service. Leaving `settings` empty lets LACT write `/etc/lact/config.yaml` while tuning; setting it in Nix makes that file a read-only symlink that the GUI cannot update.

Validate the wiring before applying it:

```bash
nix eval .#nixosConfigurations.pc-fixe.config.system.build.toplevel.drvPath --raw
sudo nixos-rebuild test --flake .#pc-fixe
systemctl status lactd
lact cli list
lact cli info
```

`vincent` is already in the `wheel` group, which is LACT's normal local-socket access group. Do not add an `admin_user` override unless the GUI reports a permission error.

Success condition: LACT reports this RTX 3080 Ti, the service survives a reboot, and opening the UI does not change any GPU setting.

## Phase 2 — record a reproducible stock baseline

Before changing a setting, capture the current state:

```bash
nvidia-smi --query-gpu=name,driver_version,temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,utilization.gpu --format=csv
journalctl -b -k | grep -Ei 'NVRM|Xid|gpu reset|hang|wedg'
```

Use the exact synthetic workload before tuning and after each confirmed Phase 3 step. `vkmark` is run temporarily, so no package needs adding to the Nix configuration.

The compositor invalidates larger swapchains in this session: `3440x1440` and Wayland runs can fail with `ErrorOutOfDateKHR` and score zero. Discard those runs. The accepted measurement uses XCB, an 800x600 window, and immediate presentation so the score is not capped at the display refresh rate.

Run exactly five times per state and compare per-scene medians plus the overall score:

```bash
mkdir -p "$HOME/.local/state/lact-benchmarks/rtx-3080-ti/stock"
timeout 480s nix run nixpkgs#vkmark -- \
  --winsys xcb \
  --use-device e06fd6eb39ecbb8060fbf561dc4037d3 \
  --size 800x600 \
  --present-mode immediate \
  --benchmark 'vertex:duration=100' \
  --benchmark 'texture:duration=100' \
  --benchmark 'shading:duration=100' \
  --benchmark 'effect2d:background-resolution=1920x1080:duration=100' \
  > "$HOME/.local/state/lact-benchmarks/rtx-3080-ti/stock/vkmark-uncapped-N.txt" 2>&1
```

`duration` is in seconds. Keep the scene list, resolution, presentation mode, GPU UUID, compositor session, and background applications unchanged. Record the score, each scene's FPS, power draw, temperature, clocks, fan mode, throttling state, and relevant kernel-driver errors.

In LACT, record the device ID returned by `lact cli list`, the allowed power-cap range, available V/F controls, memory-clock-offset range, and fan-control range. The current driver is new enough for LACT's NVIDIA clock-offset support; the UI is still the authority for what this specific card exposes.

Success condition: no artifacts, GPU resets, or NVIDIA Xid errors in the stock synthetic workload, plus five retained benchmark runs.

### Current five-run stock baseline

All five runs used the same RTX 3080 Ti UUID, XCB 800x600 window, immediate presentation, and four 100-second scenes:

| Run | Vertex | Texture | Shading | Effect2D | Score |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 8039 | 7944 | 7168 | 6449 | 7400 |
| 2 | 7514 | 8194 | 7689 | 6678 | 7518 |
| 3 | 8701 | 8715 | 8566 | 6912 | 8223 |
| 4 | 8657 | 8677 | 8593 | 6517 | 8111 |
| 5 | 8198 | 8217 | 8033 | 6628 | 7769 |
| Median | 8198 | 8217 | 8033 | 6628 | **7769** |

The stock score range is 7400–8223, so the post-tuning decision must use the five-run median and per-scene medians rather than one run.

### Current direct YAML V/F trial

This is the historical core-only trial. It intentionally predates the memory-offset and 399 W tests below, so its result must not be read as the final MSI Profile 1 result.

The core curve was applied through `lactd` and persisted to `/etc/lact/config.yaml`: 1935 MHz target at 900 mV, flattened above 900 mV, 350 W power cap, automatic fan control, and no separate memory offset. A dated debug snapshot is kept under `$HOME/.local/state/lact-benchmarks/rtx-3080-ti/`.

| Run | Vertex | Texture | Shading | Effect2D | Score |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 8101 | 8464 | 8455 | 6735 | 7938 |
| 2 | 7978 | 8170 | 8386 | 6807 | 7835 |
| 3 | 8487 | 8189 | 8218 | 6762 | 7914 |
| 4 | 8463 | 8539 | 8405 | 6792 | 8049 |
| 5 | 8410 | 8498 | 8466 | 6846 | 8055 |
| Median | 8410 | 8464 | 8405 | 6792 | **7938** |

Compared with the stock median, the overall score improved by **2.18%**; vertex, texture, shading, and Effect2D improved by 2.59%, 3.01%, 4.63%, and 2.47%. All five runs completed without vkmark errors, throttling, Xid messages, or GPU resets. This is a stable trial, but it does not meet the plan's 3% acceptance gate, so it is not Nixified yet.

## High-resolution validation results — 2026-09-06

The Wayland/vkmark swapchain failures are specific to that presentation path. A repeatable off-screen `glmark2` workload ran successfully at the actual 3440x1440 display resolution:

```bash
timeout 210s nix run nixpkgs#glmark2 -- \
  --off-screen --size 3440x1440 --swap-mode immediate \
  --benchmark 'jellyfish:duration=30' \
  --benchmark 'terrain:bloom=true:tilt-shift=true:repeat-overlay=12:duration=30' \
  --benchmark 'refract:model=asteroid-high:texture=nasa3:index=1.33:duration=30' \
  --benchmark 'shading:model=asteroid-high:shading=phong:num-lights=8:duration=30'
```

Each state completed five runs. The score and scene medians were:

| State | Core / memory behavior | Score | Jellyfish | Terrain | Refract | Shading | Delta |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Stock | automatic, 350 W, 9501 MHz memory | **12788** | 15987 | 1180 | 3921 | 30055 | — |
| Full, safe | 1935 MHz V/F target, +800 memory, 399 W, automatic fan | **12659** | 15756 | 1211 | 3951 | 29741 | **-1.01%** |

The applied profile therefore did change the hardware state: captured memory clock increased from 9501 to 9901 MHz, and LACT persisted the requested V/F curve, memory offsets, and 399 W cap. However, stock boosted as high as 1965 MHz while the tested curve held about 1935 MHz under load, and the aggregate score did not improve. The 3% performance acceptance gate is not met; the profile remains declarative only as the current tested/rollback state, not as a claimed performance improvement.

The exact Windows fan setting was also tested separately. It produced one complete run at 12733, but the next run reached 86°C GPU / 98°C VRAM-chip readings and `SW_THERMAL_SLOWDOWN` at a fixed 35% fan, so it was aborted. The machine is intentionally left on the safer version: the full curve, +800 memory, and 399 W limit with automatic fan control.

### Community-style offset replication — 2026-09-06

To test the common review/owner setup directly, the live LACT GPU config was temporarily changed to `gpu_clock_offsets=+130`, `mem_clock_offsets=+500`, `power_cap=399`, automatic fan control, and no NVIDIA V/F curve. Two complete 3440x1440 off-screen `glmark2` passes scored **13521** and **13608**, compared with the stock median of **12788**. The third pass reached 100°C on multiple VRAM-chip sensors and was aborted before thermal slowdown, so this is promising evidence rather than a five-run acceptance result. The temporary offset profile was removed and the Nix-managed automatic-fan V/F profile was restored.

Raw results are retained under:

- `$HOME/.local/state/lact-benchmarks/rtx-3080-ti/clean-stock-heavy-3440x1440-20260905-235952`
- `$HOME/.local/state/lact-benchmarks/rtx-3080-ti/clean-full-auto-heavy-3440x1440-20260906-0020`
- `$HOME/.local/state/lact-benchmarks/rtx-3080-ti/clean-full-msi-3440x1440-20260906-0015`

## Automated profile and GPU stress tool

The Nix configuration reads `modules/graphics/assets/lact-settings.json` through `services.lact.settings`. It retains the verified MSI-derived V/F profile in the source asset as reference, but excludes it from generated daemon YAML because Nix serializes its numeric curve keys as strings and LACT rejects them. The generated daemon config selects the `community-typical` profile, which uses `+130` per-state GPU offsets, `+400` memory, and a 399 W cap with automatic fan control. The fixed 35% fan is intentionally excluded from automation. The Home Manager applier replaces the complete GPU config instead of merging it, preventing stale fields from surviving when switching between offset and V/F profiles.

The CUDA-enabled stress tool is exposed as a Linux flake package:

```bash
nix run .#gpu-burn -- -i 0 -tc -m 70% 120
```

The first real run used that workload with one-second `nvidia-smi` telemetry. It reported zero arithmetic errors for about 96 seconds (80% progress) and reached the 399 W cap, but was stopped after VRAM sensors reached 98°C. Follow-up runs at 40% and 10% allocation, including a temporary 300 W / stock-memory control, reached 96–100°C before 120 seconds as well. Record `gpu-burn` as a working CUDA/error detector with a GDDR6X thermal limit, not as a clean full-memory 120-second pass; use the high-resolution `glmark2` suite for performance comparisons.

The profile is validated by `nix eval` and `nix flake check`. A Home Manager user service named `lact-profile-community-typical.service` is also active and reapplies the same profile through the LACT Unix socket at graphical-session startup, so the automated overclock procedure is live without requiring a root-owned file change. Converting `/etc/lact/config.yaml` into a read-only NixOS-managed symlink still requires the normal privileged activation.

Activate it with:

```bash
sudo nixos-rebuild switch --flake /home/vincent/.nixfiles#pc-fixe
readlink -f /etc/lact/config.yaml
lact cli profile get
```

The expected post-activation checks are a Nix-store target for the config path and `community-typical` as the current LACT profile. Until then, verify the user-level automation with `systemctl --user status lact-profile-community-typical.service`; its successful API transaction is the authoritative live check.

## Phase 3 — tune in the smallest safe increments

Use LACT's GUI or local API for this phase. Its generated config is the source of truth; do not hand-write an unverified V/F-curve schema.

1. Leave the power cap at 350 W and keep fans automatic. Confirm the V/F editor is available.
2. Recreate only the core curve: 1935 MHz at 900 mV, flattening above 900 mV. Do not set a separate global core offset.
3. Confirm the setting in LACT, then repeat the Phase 2 synthetic benchmark plus a sustained GPU-heavy workload. Monitor continuously:

   ```bash
   watch -n1 'nvidia-smi --query-gpu=temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,utilization.gpu --format=csv'
   journalctl -kf | grep -Ei 'NVRM|Xid|gpu reset|hang|wedg'
   ```

4. If the curve is stable, add the `+800 MHz` memory offset and repeat the same tests. Revert immediately for artifacts, corrupted textures, a reset, or an Xid error.
5. If both are stable, raise the power cap from 350 W to 399 W and repeat the tests. Do not round beyond the driver-reported 400 W maximum.
6. Only if thermals or acoustics require it, add a temperature-based fan curve. Keep the fixed 35% fan value out unless it is actually preferable under Linux.

After every confirmed change, save a dated copy of `/etc/lact/config.yaml` outside `/etc/lact` and inspect its diff. This protects against accidental configuration drift, including V/F-curve loss when changing an unrelated option.

Keep a change only when its five-run synthetic medians show a repeatable overall-score gain of at least 3%, with no material per-scene regression, thermal throttling, artifacts, or relevant kernel-driver error. Otherwise revert it: a higher reported clock without a measurable synthetic gain is not a useful overclock.

Success condition for each step: clean idle, the repeated synthetic workload, a memory-heavy `effect2d` scene, suspend/resume, and one reboot with no artifacts or relevant kernel-driver error.

## Phase 4 — make only the proven profile declarative

Once every target has passed the Phase 3 checks:

1. Start from the LACT-generated `/etc/lact/config.yaml`; retain only the explicit working GPU entry and the minimum daemon configuration.
2. Replace the mutable file with `services.lact.settings` in `modules/graphics.nix`, using the LACT-reported device ID—not the old Windows BDF.
3. Keep a single explicit current profile. Do not add process/Gamemode profile switching; the startup-selected profile is sufficient and avoids applying the experimental tuning to every desktop process.
4. Run the Phase 1 validation again, then reboot and repeat the acceptance workload.

This is intentionally a two-step configuration: LACT's exact NVIDIA V/F representation must be generated by the current tool and driver first. Nix should freeze tested data, not guess a schema for undocumented driver controls.

## Recovery

For a change that fails in the desktop session, decline LACT's confirmation dialog or restore the last saved config and restart `lactd`.

For a confirmed setting that prevents graphical login, boot once with the kernel parameter `lact-reset`. LACT resets its configuration and saves the previous config under another name in `/etc/lact`. Remove that parameter after recovery; leaving it enabled resets the configuration at every service start.

Once settings are Nix-managed, boot the previous NixOS generation if the declarative profile is the cause. Keep the last known-good LACT YAML beside the plan until the profile has passed at least a week of normal use.

## Acceptance checklist

- LACT controls the card through `lactd` without an X11 dependency.
- The selected V/F curve is present after reboot and has not been replaced by a scalar core offset.
- Memory offset and 399 W cap remain within driver-reported limits.
- Automatic fans remain adequate, or a tested temperature curve is in place.
- Five identical synthetic benchmark runs are retained; the accepted profile improves the median `vkmark` score by at least 3% without a material per-scene regression.
- No claim is made about GTA IV FPS because its built-in benchmark crashed in this environment.
- No artifacts, Xid errors, GPU resets, suspend/resume regressions, or gaming regressions occur over a week of normal use.
- `services.lact.settings` contains only confirmed values and no automatic profile switching.
- The CUDA stress tool is available as `nix run .#gpu-burn`, with telemetry and a thermal abort.

## Sources

- [NixOS LACT module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/hardware/lact.nix): enabling the service installs LACT; managed `settings` makes `/etc/lact/config.yaml` immutable to the GUI.
- [LACT configuration reference](https://github.com/ilya-zlobintsev/LACT/blob/master/docs/CONFIG.md): config location, GPU IDs, clock-offset fields, and the settings-confirmation timer.
- [LACT hardware support](https://github.com/ilya-zlobintsev/LACT/wiki/Hardware-support): Ampere support and the driver-version guidance for NVIDIA clock offsets.
- [LACT NVIDIA V/F release notes](https://github.com/ilya-zlobintsev/LACT/releases): the editor uses undocumented NVIDIA driver functionality and carries no stability guarantee.
- [LACT bad-overclock recovery](https://github.com/ilya-zlobintsev/LACT/wiki/Recovering-from-a-bad-overclock): temporary `lact-reset` boot parameter.
- [LACT API](https://github.com/ilya-zlobintsev/LACT/blob/master/docs/API.md): Unix-socket configuration changes require explicit confirmation.
- [gpu-burn](https://github.com/wilicc/gpu-burn): CUDA stress test used for stability validation, not performance scoring.
