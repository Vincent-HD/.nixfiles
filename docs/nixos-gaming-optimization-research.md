# Gaming optimization for NixOS

Research date: 2026-08-19

## Conclusion

NixOS can reproduce most of the useful parts of CachyOS and Bazzite, but I did not find a single maintained project that ports the complete experience as one drop-in gaming distribution.

The closest composable stack is:

1. [nix-gaming](https://github.com/fufexan/nix-gaming) for SteamOS platform sysctls, low-latency PipeWire, Wine/Proton packages, and gaming modules.
2. [Chaotic Nyx](https://github.com/chaotic-cx/nyx) or [nix-cachyos-kernel](https://github.com/xddxdd/nix-cachyos-kernel) for CachyOS kernels and newer gaming packages.
3. Native NixOS modules for GameMode, Gamescope, MangoHud, ZRAM, power profiles, and sched-ext.

For this repository, the implementation is a focused gaming-optimization module: it imports only nix-gaming's `platformOptimizations` module, keeps the existing gaming stack, and uses the tested CachyOS kernel as the default. A `stock` boot specialization remains available as an explicit fallback.

## What is actually being copied

### CachyOS

CachyOS combines several independent layers: optimized kernels with BORE/EEVDF/BMQ schedulers, LTO and profile-guided builds, architecture-specific binaries, CachyOS process-priority rules, custom Proton/Wine builds, power-profile switching, and gaming tools. Its own guide warns that optimizations can produce minor or no gains depending on the game and hardware ([gaming guide](https://wiki.cachyos.org/configuration/gaming/), [kernel source](https://github.com/CachyOS/linux-cachyos), [process rules](https://github.com/CachyOS/ananicy-rules)).

### Bazzite

Bazzite is more than a tuning profile: it is an immutable Fedora Atomic image with integrated drivers, HDR/VRR, Gamescope/Steam gaming mode, MangoHud/vkBasalt, controller support, automatic updates and rollback. Its handheld/HTPC variant additionally uses ZRAM, LAVD/BORE schedulers, Kyber I/O scheduling, and SteamOS kernel parameters ([Bazzite feature list](https://github.com/ublue-os/bazzite)). Reproducing those pieces on NixOS is possible, but it does not form one equivalent image unless the whole host is redesigned around a SteamOS-like session.

## NixOS candidates

| Project | What it provides | Fit |
| --- | --- | --- |
| **[Chaotic Nyx](https://github.com/chaotic-cx/nyx)** | CachyOS kernels with claimed upstream kconfig parity, `nvidia_cachyos`, `zfs_cachyos`, sched-ext integration, bleeding-edge Mesa/Gamescope, and a binary cache | **Broadest CachyOS-oriented source.** It is intentionally bleeding-edge and adds a large overlay/cache trust boundary. |
| **[nix-cachyos-kernel](https://github.com/xddxdd/nix-cachyos-kernel)** | CachyOS-patched/tuned kernels and ZFS, with release-branch Hydra builds and a binary cache | **Best kernel-only option.** It does not reproduce CachyOS userspace, Proton, power management, or process rules. Its README explicitly warns that mismatched nixpkgs revisions can cause cache misses or local kernel builds. |
| **[nix-gaming](https://github.com/fufexan/nix-gaming)** | `platformOptimizations`, low-latency PipeWire, gaming packages, Wine/Proton variants, and GameMode guidance | **Best first addition.** Its `platformOptimizations` module applies the SteamOS sysctl set: scheduler bandwidth slice, TCP FIN timeout, split-lock mitigation, and a high `vm.max_map_count`. |
| **[Jovian-NixOS](https://jovian-experiments.github.io/)** | SteamOS-like Gamescope session and dedicated gaming-PC/Steam-Deck configuration | **Best Bazzite/SteamOS-style experience**, especially for a living-room or handheld host; unnecessary for a normal Niri desktop. |
| Native NixOS | GameMode, Gamescope, MangoHud, ZRAM, `services.scx`, `power-profiles-daemon`, `linux-zen`, and CachyOS Ananicy rules are available in the current ecosystem | **Cleanest long-term base**, but requires choosing and validating each tuning layer. |

## Current repository assessment

This configuration already has a good gaming foundation:

- Steam, Gamescope, Gamescope session, GameMode, MangoHud, Proton-GE, Heroic, and Lutris in [`modules/gaming.nix`](/home/vincent/.nixfiles/modules/gaming.nix).
- ZRAM and earlyoom in [`modules/memory-pressure.nix`](/home/vincent/.nixfiles/modules/memory-pressure.nix).
- Power profiles through [`modules/dms/dms.nix`](/home/vincent/.nixfiles/modules/dms/dms.nix).
- The nix-gaming Cachix cache is trusted in [`hosts/pc-fixe/configuration.nix`](/home/vincent/.nixfiles/hosts/pc-fixe/configuration.nix), and the CachyOS kernel cache is configured by [`modules/gaming-optimization.nix`](/home/vincent/.nixfiles/modules/gaming-optimization.nix).

The local nixpkgs currently provides `linux-zen`, `ananicy-cpp`, and `ananicy-rules-cachyos`; it does not expose `linuxPackages_cachyos`. The dedicated kernel input now supplies `linuxPackages-cachyos-latest-x86_64-v3` as the default and keeps `linuxPackages` available in the `stock` specialization. The host also builds a custom CPUID-fault-emulation module and uses NVIDIA; evaluation confirms both follow whichever kernel entry is selected.

## Important conflict to avoid

Do not enable every “gaming optimizer” at once. CachyOS explicitly warns about combining GameMode and Ananicy because both can change process niceness. This repository already enables GameMode. If Ananicy or sched-ext is introduced, the priority behavior should be tested deliberately, with one change at a time ([CachyOS rules README](https://github.com/CachyOS/ananicy-rules), [CachyOS sched-ext guide](https://wiki.cachyos.org/configuration/sched-ext/)).

## What nix-gaming's platform optimizations actually do

`nix-gaming` is a collection of independent packages and NixOS modules, not one all-or-nothing gaming distribution. The `platformOptimizations` module is particularly small. Its implementation sets only these four kernel/network sysctls ([module source](https://raw.githubusercontent.com/fufexan/nix-gaming/master/modules/platformOptimizations.nix)):

- `kernel.sched_cfs_bandwidth_slice_us = 3000` — changes the CFS scheduler's bandwidth slice.
- `net.ipv4.tcp_fin_timeout = 5` — shortens the time TCP keeps closed connections around.
- `kernel.split_lock_mitigate = 0` — disables the kernel's split-lock mitigation.
- `vm.max_map_count = 2147483642` — raises the maximum number of memory mappings, which some games and compatibility layers need.

It does not install all of nix-gaming's Wine/Proton or game packages, change the kernel, enable GameMode, enable Ananicy or sched-ext, or replace the desktop session. Adding the flake input and importing only `nixosModules.platformOptimizations` therefore does not add the project's unrelated “garbage” to the installed system. The other nix-gaming modules and packages remain opt-in.

## Which option is best for this host?

My recommendation for the always-on baseline is **nix-gaming's `platformOptimizations` module**. It is narrow and does not add a large overlay, a process-priority daemon, or a new desktop session. For this host, the tested `nix-cachyos-kernel` package is now the default kernel, with the stock kernel retained only as a fallback specialization.

For the larger alternatives:

- **Best CachyOS-style source overall: Chaotic Nyx.** It is the broadest option and provides CachyOS kernels, newer graphics/gaming packages, and sched-ext integration, but it is deliberately bleeding-edge and expands both the overlay and binary-cache trust boundary.
- **Best kernel-only option: `nix-cachyos-kernel`.** It is the better fit if the goal is specifically a CachyOS kernel without importing a large package ecosystem. This host uses NVIDIA and a custom out-of-tree kernel module, so both the default and stock fallback paths are validated.
- **Best Bazzite/SteamOS-like experience: Jovian-NixOS.** It targets a Gamescope/Steam-Deck-style appliance session, which is not what this normal Niri desktop needs.

So the module uses nix-gaming and the kernel-only `nix-cachyos-kernel` input, while avoiding Nyx merely to obtain the four sysctls or a CachyOS kernel.

## What the other optimizers are, where they are, and whether we need them

| Component | What it does | Current location/status | Do we need it now? |
| --- | --- | --- | --- |
| **GameMode** | Lets a game request temporary CPU/GPU, I/O, and process-priority adjustments while it runs. | Enabled in [`modules/gaming.nix`](/home/vincent/.nixfiles/modules/gaming.nix). | **Yes, keep it.** It is already part of the working gaming setup. |
| **`platformOptimizations`** | The four sysctls listed above; it is not a daemon or scheduler. | Imported and enabled by [`modules/gaming-optimization.nix`](/home/vincent/.nixfiles/modules/gaming-optimization.nix). | **Yes, enabled.** |
| **Ananicy-cpp** | A background daemon that applies nice/priority rules to processes automatically. | `ananicy-cpp` and `ananicy-rules-cachyos` are available in current nixpkgs, but `services.ananicy` is not enabled in this repo. | **No for now.** It overlaps with GameMode and is easy to mis-tune. |
| **sched-ext / SCX** | A kernel interface that lets a userspace scheduler such as `scx_rustland` or `scx_rusty` make scheduling decisions. | The NixOS `services.scx` option exists, but the service is disabled and no scheduler is selected here. | **No for now.** It is an experiment for latency/throughput trade-offs, not a universal FPS switch. |
| **CachyOS kernel** | A separately patched kernel with different schedulers, compiler/link-time settings, and hardware-tuned variants. | The x86-64-v3 variant from `nix-cachyos-kernel` is the default; the stock kernel is available through the `stock` specialization. | **Enabled by default.** Kernel/module/NVIDIA compatibility has been evaluated; runtime benchmarking can still compare it with the stock fallback. |
| **ZRAM, earlyoom, power profiles** | Memory-pressure protection and power/performance policy switching. | ZRAM/earlyoom are in [`modules/memory-pressure.nix`](/home/vincent/.nixfiles/modules/memory-pressure.nix); power profiles are enabled in [`modules/dms/dms.nix`](/home/vincent/.nixfiles/modules/dms/dms.nix). | **Already covered.** No duplicate optimizer is needed. |

## Implemented default and fallback path

1. Apply the configuration with `sudo nixos-rebuild switch --flake .#pc-fixe`. This enables nix-gaming's four sysctls and makes CachyOS the normal kernel, with a `stock` boot specialization in the same generation.
2. Reboot and use the normal systemd-boot entry. The generated entry currently includes `(Linux 7.2.0-cachyos)` in its label. Verify the running kernel with `uname -r`; it should report `7.2.0-cachyos`.
3. If needed, choose the `stock` specialization and verify that it reports the current nixpkgs kernel (`6.18.45` in the evaluated configuration).
4. Compare identical games, settings, and workloads on the default and `stock` entries. Record average FPS, 1% lows, frametime variance, input latency, suspend/resume, and NVIDIA behavior.
5. Do not add Ananicy, sched-ext, or a second kernel scheduler until this isolated comparison has a clear result. If CachyOS causes a regression, use the `stock` entry or remove the default assignment without changing the nix-gaming sysctls.

The implementation is in [`modules/gaming-optimization.nix`](/home/vincent/.nixfiles/modules/gaming-optimization.nix), enabled by [`hosts/pc-fixe/default.nix`](/home/vincent/.nixfiles/hosts/pc-fixe/default.nix). No Ananicy or sched-ext configuration was added.
