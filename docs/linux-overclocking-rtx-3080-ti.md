# Linux overclocking notes — RTX 3080 Ti

Recovered from the installed Windows ChatGPT/Codex instance on 2026-09-05.

- Windows worktree: `C:\Users\Vincent\Documents\Codex\2026-09-05\i-x20`
- Linux-mounted source: `/mnt/windows/Users/Vincent/Documents/Codex/2026-09-05/i-x20`
- Session: `01a06ecd-6db6-7231-86e3-e4c649374be4`
- Original MSI Afterburner files were not modified.

## Conversation

### User

> I have a msi afterburner preset to overclock my graphic card, but on a daily basis i'm using linux, spin up as many agent as you want to try to figure out what is the best way to do it.
>
> also extract the profile 1 from my msi afterburner in another subagent

### Assistant — progress

> I’ll split this into parallel tracks: identify the Linux-side equivalent of your Afterburner profile, inspect the workspace for the actual MSI Afterburner config/profile, and separately extract Profile 1 so we can map it precisely. I’ll also keep the result hardware-safe: the exact Linux method depends heavily on your GPU vendor/model, driver, and whether the preset includes voltage, power-limit, or fan-curve changes.

> The parallel extraction and research agents are running. I’m checking the local Windows profile locations now; I’ll keep the originals untouched and use the extracted values as the source of truth for the Linux conversion.

> The local machine contains the preset. It identifies an NVIDIA GeForce RTX 3080 Ti, and the actual per-GPU Profile 1 data is stored in the device-specific config—not in the tiny `Profile1.cfg` launcher file. The key values already visible are 114% power limit, −300 MHz core offset, +800 MHz memory offset, and a fixed 35% fan setting; the profile also embeds a full V/F curve.

### Assistant — final answer

> Done. Your card is an NVIDIA GeForce RTX 3080 Ti.
>
> Profile 1 contains:
>
> - Power limit: 114%
> - Core offset: −300 MHz
> - Memory offset: +800 MHz
> - Manual fan: 35%
> - Custom V/F curve: approximately 1935 MHz at 900 mV, flattened above 900 mV
> - No voltage boost or thermal-limit override
>
> Best Linux approach: use LACT. It supports NVIDIA clock, memory, power, fan, and recent V/F-curve controls through a system service independent of X11/Wayland. Recreate the profile manually there; do not apply both the −300 MHz scalar and the already-adjusted V/F curve, or you may double-apply the offset.
>
> Use `nvidia-settings` only as a fallback. Under X11, NVIDIA’s `Coolbits=12` enables clock offsets plus fan control; it cannot faithfully reproduce the custom V/F curve.
>
> The original MSI files were not modified.

=====

# MSI Afterburner Profile 1 extraction

## Matched hardware

- GPU: NVIDIA GeForce RTX 3080 Ti
- PCI identity: `VEN_10DE&DEV_2208&SUBSYS_153510DE&REV_A1&BUS_43&DEV_0&FN_0`
- Source file: `C:\Program Files (x86)\MSI Afterburner\Profiles\VEN_10DE&DEV_2208&SUBSYS_153510DE&REV_A1&BUS_43&DEV_0&FN_0.cfg`
- Source-file SHA-256: `BA823CC07DF986940408E4A81917B888B45EDB208AD55DC4B79B95F2642DC5AD`

`Profiles\Profile1.cfg` is only a marker containing `ProfileContents=1`; the actual GPU settings are in the matched device-specific file above.

## Exact Profile1 scalar fields

```ini
[Profile1]
Format=2
CoreVoltageBoost=0
PowerLimit=114
ThermalLimit=
ThermalPrioritize=0
CoreClkBoost=-300000
MemClkBoost=800000
FanMode=1
FanSpeed=35
FanMode2=
FanSpeed2=
```

Likely UI equivalents:

- Power limit: 114% of the card's default target
- Core offset: -300 MHz (`-300000` stored in kHz)
- Memory offset: +800 MHz transfer-rate offset (`800000` stored in kHz)
- Fan: manual, fixed 35%
- Core-voltage scalar boost: 0
- No explicit thermal-limit override

## V/F curve summary

The profile contains a 6,448-character / 3,224-byte hex-encoded V/F curve with 127 active records. Decoding the observed format as voltage, base frequency, and per-point offset gives:

- Voltage coordinates: 450.00–1237.50 mV in 6.25 mV steps
- Base-frequency range: 315–2235 MHz
- Applied-frequency range (`base + offset`): 15–1935 MHz
- The curve reaches 1935 MHz at 900 mV and remains flat at 1935 MHz above that point.
- The only per-point offset different from the global -300 MHz is the 900 mV point: base 1735 MHz plus a +200 MHz point offset = 1935 MHz.

This is a custom undervolt/curve profile, not just a plain scalar offset. The hex blob is intentionally not copied into a Linux config because it is an MSI/Windows-specific format.

=====

# Linux plan for the extracted RTX 3080 Ti profile

## Recommended path

Use LACT as the daily profile manager on Linux. It has a system service that can apply settings independently of X11/Wayland, supports NVIDIA power/fan/clock controls, and provides an NVIDIA V/F-curve editor on recent releases. Use one manager only; do not run LACT, CoreCtrl, GreenWithEnvy, and custom `nvidia-settings` reapply scripts together.

Recreate Profile 1 in LACT as:

1. V/F curve: 900 mV at 1935 MHz, flattening at 1935 MHz above 900 mV.
2. Memory: start at +800 MHz transfer-rate offset, then verify the actual memory clock reported by the driver.
3. Power: query the card's absolute default/min/max watt limits and set the Linux value corresponding to 114%, clamped to the reported maximum. Do not assume 114% means a universal watt value.
4. Fan: fixed 35% only if you truly want the Windows behavior; a temperature curve is usually better for daily Linux use.

The original curve should be treated as a starting point. Confirm stability on the Linux driver with real workloads before enabling automatic application.

## Lower-level NVIDIA fallback

This reproduces the scalar parts only and requires the proprietary NVIDIA driver plus an X/NV-CONTROL path:

```bash
# Probe first; only use attributes that the running driver reports.
nvidia-smi
nvidia-settings -q '[gpu:0]/GPUPerfModes'
nvidia-settings -q '[gpu:0]/GPUGraphicsClockOffsetAllPerformanceLevels'
nvidia-settings -q '[gpu:0]/GPUMemoryTransferRateOffsetAllPerformanceLevels'
nvidia-smi --query-gpu=power.limit,power.default_limit,power.min_limit,power.max_limit --format=csv

# Scalar offsets from Profile 1; this does NOT reproduce its 900 mV V/F curve.
nvidia-settings \
  -a '[gpu:0]/GPUGraphicsClockOffsetAllPerformanceLevels=-300' \
  -a '[gpu:0]/GPUMemoryTransferRateOffsetAllPerformanceLevels=800'

# Only if a fixed 35% fan is desired and the attribute is available.
nvidia-settings \
  -a '[gpu:0]/GPUFanControlState=1' \
  -a '[gpu:0]/GPUTargetFanSpeed=35'
```

For Xorg, NVIDIA documents Coolbits bit 3 (`8`) for clock offsets and bit 2 (`4`) for fan control, so `Coolbits=12` is the relevant combination. NVIDIA explicitly marks Coolbits unsupported and warns about hangs, data loss, hardware damage, and warranty impact.

## Validation and rollback

Before changing anything, record the current power limit and offsets. Monitor the actual result:

```bash
watch -n1 'nvidia-smi --query-gpu=temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,utilization.gpu --format=csv'
journalctl -kf | grep -Ei 'NVRM|Xid|gpu reset|hang|wedg'
```

Reset scalar offsets and fan control with:

```bash
nvidia-settings \
  -a '[gpu:0]/GPUGraphicsClockOffsetAllPerformanceLevels=0' \
  -a '[gpu:0]/GPUMemoryTransferRateOffsetAllPerformanceLevels=0' \
  -a '[gpu:0]/GPUFanControlState=0'
```

Do not automate the profile until idle, sustained graphics, memory-heavy, suspend/resume, and reboot tests are clean.

## References from the original conversation

- [LACT](https://github.com/ilya-zlobintsev/LACT)
- [LACT hardware support](https://github.com/ilya-zlobintsev/LACT/wiki/Hardware-support)
- [NVIDIA Coolbits documentation](https://download.nvidia.com/XFree86/Linux-x86_64/450.57/README/xconfigoptions.html)
