# LSFG-VK research handoff

Research date: 2026-08-29

Scope: current LSFG-VK v2 documentation and source only. Sources used are the official documentation at [lsfg-vk.dev](https://lsfg-vk.dev/), the official self-hosted source repository at [git.lsfg-vk.dev/lsfg-vk](https://git.lsfg-vk.dev/lsfg-vk/), and its official GitHub source mirror where the current files are directly browsable at [github.com/PancakeTAS/lsfg-vk](https://github.com/PancakeTAS/lsfg-vk). No configuration change is proposed here.

## Executive handoff

The intended NixOS integration is a Linux-only package/module for the Vulkan implicit layer, `lsfg-vk-cli`, and optionally the Qt6 UI. It should package a pinned v2 source/archive, install the layer manifest and library together, point the manifest at the immutable Nix-store library path, expose the CLI/UI, and leave per-game activation to an `LSFGVK_PROFILE='Profile name' %command%` Steam launch option or an `active_in` profile. The implementation must validate layer discovery with `vulkaninfo`, exercise `vkcube`, and run one real Vulkan Proton game before considering the feature complete.

Do not copy old v1 wiki instructions into the implementation. Current v2 uses `VK_LAYER_LSFGVK_frame_generation`, `liblsfg-vk-layer.so`, a version-2 TOML configuration, and `DISABLE_LSFGVK`; the old wiki/source-era names such as `VkLayer_LS_frame_generation`, `liblsfg-vk.so`, `ENABLE_LSFG`, and old GPU environment options are version-sensitive or obsolete. The maintainer’s migration note says v2 is a rewrite and that the old GitHub repository is archived: [Important changes to lsfg-vk](https://lsfg-vk.dev/blog/important-changes-to-lsfg-vk/).

## Upstream facts

### Prerequisites and support

- Lossless Scaling must already be installed through Steam: [installation guide](https://lsfg-vk.dev/docs/installation/), [official Steam app](https://store.steampowered.com/app/993090/Lossless_Scaling/).
- LSFG-VK is intended for Linux systems with Vulkan support. The project says that a GPU with a Vulkan driver should generally work, while warning that users have reported extremely poor performance on dedicated Intel GPUs: [project overview](https://lsfg-vk.dev/).
- The target application must use Vulkan, not OpenGL. The current troubleshooting guide also asks for a 64-bit application; for a 32-bit Proton application it suggests trying `PROTON_USE_WOW64=1`, but says that failure leaves the application unsupported: [basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/).
- A source build requires common build tools, a C++20-or-newer compiler, CMake 3.10 or newer, Ninja (recommended), and the Vulkan SDK. Qt6 and Qt6Quick are required only for `lsfg-vk-ui`: [building from source](https://lsfg-vk.dev/docs/installation/building-from-source/).
- The v2 migration note says the required Vulkan version was dropped to 1.2 to broaden GPU compatibility. The current source creates the internal frame-generation device with Vulkan 1.2 and uses external memory/semaphore file-descriptor extensions, timeline semaphores, and synchronization2: [migration note](https://lsfg-vk.dev/blog/important-changes-to-lsfg-vk/), [current pipeline source](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-pipeline/src/lsfgvk.cpp).
- Dual-GPU support is not a current feature; the project overview lists it as future work. The current layer passes the application’s physical device to the internal generation pipeline, so an implementation should not invent a separate-GPU configuration path: [project overview](https://lsfg-vk.dev/), [current layer wrapper](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/src/wrapper.cpp).

### Installation and file layout

- The current installation page recommends a distribution package when one exists. Otherwise, it directs users to a prebuilt archive from `builds.lsfg-vk.dev`, compiled on Ubuntu 22.04, and extracts it under `~/.local`: [installation guide](https://lsfg-vk.dev/docs/installation/), [build archive index](https://builds.lsfg-vk.dev/).
- The manual install is not self-cleaning. The docs require tracking the extracted files; `lsfg-vk-cli validate -l` can list manually installed files later: [installation guide](https://lsfg-vk.dev/docs/installation/), [validation](https://lsfg-vk.dev/docs/cli/validation/).
- A source install defaults to `/usr/local`. The build can enable the layer, CLI, and UI independently; `LSFGVK_LAYER_LIBRARY_PATH` controls the path written into the Vulkan manifest; `LSFGVK_LAYER_MULTILIB_X86` enables a 32-bit multilib layer; and `LSFGVK_MANAGED=ON` tells the project that a package manager owns the files: [building from source](https://lsfg-vk.dev/docs/installation/building-from-source/), [top-level CMake](https://github.com/PancakeTAS/lsfg-vk/blob/develop/CMakeLists.txt).
- The current layer CMake installs the shared library to `${CMAKE_INSTALL_LIBDIR}` and the generated manifest to `${CMAKE_INSTALL_DATAROOTDIR}/vulkan/implicit_layer.d`. The CLI and UI are installed as normal executables; the UI also installs a desktop file and icon: [layer CMake](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/CMakeLists.txt), [CLI CMake](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-cli/CMakeLists.txt), [UI CMake](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-ui/CMakeLists.txt).
- The current manifest identifies the layer as `VK_LAYER_LSFGVK_frame_generation`, has type `GLOBAL`, contains a configured `library_path`, and disables itself when `DISABLE_LSFGVK=1`: [manifest template](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/VkLayer_LSFGVK_frame_generation.json.in).
- The v2 migration note says prebuilt releases include a 32-bit layer. A source package must deliberately decide whether to build/install that optional artifact: [migration note](https://lsfg-vk.dev/blog/important-changes-to-lsfg-vk/), [layer CMake](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/CMakeLists.txt).
- The current source is licensed CC BY-NC-ND 4.0, not the old v1 license. Check redistribution and packaging implications before publishing a Nix package: [official source license](https://git.lsfg-vk.dev/lsfg-vk/tree/LICENSE.txt), [migration note](https://lsfg-vk.dev/blog/important-changes-to-lsfg-vk/).

### Vulkan layer registration and activation

- LSFG-VK is a Vulkan implicit layer. Its normal activation mechanism is registration of the manifest in a Vulkan implicit-layer directory; the layer then decides whether a matching profile exists. The current implementation hooks instance/device/swapchain creation and presentation only for a supported, matching application: [layer manifest](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/VkLayer_LSFGVK_frame_generation.json.in), [layer implementation](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/src/layer.cpp), [technical explanation](https://lsfg-vk.dev/blog/injecting-into-a-vulkan-app/).
- The current layer adds the instance/device extensions needed for external memory and semaphore sharing and enables timeline semaphores. It requires a swapchain-capable application and modifies swapchain images so it can copy frames in and out: [current hooks](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/src/hooks.cpp), [current Vsync mode](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/src/modes/vsync.cpp).
- The old technical blog post is explicitly tagged outdated and mentions an old `ENABLE_LSFG` mechanism. Current v2 manifest/source use `DISABLE_LSFGVK` and profile matching; the implementation plan must follow the current manifest/source, not that old name: [outdated technical post](https://lsfg-vk.dev/blog/injecting-into-a-vulkan-app/), [current environment-variable page](https://lsfg-vk.dev/docs/configuration/environment-variables/), [current manifest](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-layer/VkLayer_LSFGVK_frame_generation.json.in).

### Configuration

- Configuration is TOML version 2 with one `[global]` section and one or more `[[profile]]` sections. Profiles can be selected by `active_in`, and global settings apply to every profile: [configuration](https://lsfg-vk.dev/docs/configuration/).
- Global options are `dll`, `allow_fp16`, and hidden logging options `log_level` and `log_file`. The current docs say FP16 is enabled by default; it can substantially improve AMD performance, does not change quality, and can reduce performance on older NVIDIA GPUs: [configuration options](https://lsfg-vk.dev/docs/configuration/configuration-options/).
- Profile options are `name`, `active_in`, `multiplier`, `flow_scale`, `performance_mode`, `pacing`/`pacing_mode`, and `override_present_mode`. `active_in` may contain Linux binary names, Windows executable names, process names, or a path suffix. Lower flow scale favors performance over quality; performance mode uses a lighter model: [configuration options](https://lsfg-vk.dev/docs/configuration/configuration-options/).
- The only current pacing mode is Vsync. It requires Vsync in the game; the docs warn about skipped/duplicated frames, added latency, exact-refresh-rate constraints, and VRR problems. `override_present_mode` defaults to true and forces FIFO/Vsync behavior: [pacing modes](https://lsfg-vk.dev/docs/configuration/pacing-modes/), [configuration options](https://lsfg-vk.dev/docs/configuration/configuration-options/).
- Multiplier, flow scale, and performance mode are hot-reloadable. Pacing changes or removing a profile require swapchain recreation, usually by resizing or restarting the application: [configuration options](https://lsfg-vk.dev/docs/configuration/configuration-options/).
- There is a documentation/source naming discrepancy: the web configuration page says `~/.config/lsfg-vk/config.toml`, while the current v2 source, Flatpak instructions, and CLI examples use `~/.config/lsfg-vk/conf.toml`. The current source resolves `LSFGVK_CONFIG` first, then `XDG_CONFIG_HOME/lsfg-vk/conf.toml`, then `$HOME/.config/lsfg-vk/conf.toml`: [web configuration page](https://lsfg-vk.dev/docs/configuration/), [current config source](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/src/config.cpp), [Flatpak guide](https://lsfg-vk.dev/docs/installation/flatpak/). For a current v2 package, use `conf.toml` and set `LSFGVK_CONFIG` explicitly if reproducibility requires an unambiguous path.
- The current source accepts both `pacing_mode` and the older `pacing` spelling when reading profile TOML. Use one spelling consistently and run `validate`: [current config parser](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/src/config.cpp).

### Environment variables and Steam/Proton use

- Always-supported control variables are `DISABLE_LSFGVK`, `LSFGVK_CONFIG`, and `LSFGVK_PROFILE`. `LSFGVK_PROFILE` names a profile and overrides automatic profile detection: [environment variables](https://lsfg-vk.dev/docs/configuration/environment-variables/).
- With `LSFGVK_ENV=1`, configuration can be supplied without a TOML file using `LSFGVK_DLL_PATH`, `LSFGVK_NO_FP16`, `LSFGVK_LOG_LEVEL`, `LSFGVK_LOG_FILE`, `LSFGVK_MULTIPLIER`, `LSFGVK_FLOW_SCALE`, `LSFGVK_PERFORMANCE_MODE`, `LSFGVK_PACING_MODE`, and `LSFGVK_OVERRIDE_PRESENT_MODE`: [environment variables](https://lsfg-vk.dev/docs/configuration/environment-variables/), [current config parser](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/src/config.cpp).
- The current v2 parser does not implement the old `LSFGVK_GPU` profile/environment path; the field is commented out in the current source. Do not add a GPU selector based on stale v1 wiki text: [current config header](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/include/lsfg-vk-utils/config.hpp), [current config parser](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/src/config.cpp).
- The recommended per-game Steam launch-option form is `LSFGVK_PROFILE='Profile name' %command%`. Alternatively, add the game executable to `active_in`, which the getting-started guide describes as the convenient automatic method: [getting started](https://lsfg-vk.dev/docs/getting-started/).
- For Proton, profile matching can inspect the Windows executable mapped in the Wine/Proton process; the current source also supports matching the `SteamAppId` environment value. Therefore a profile can use an executable suffix or a Steam App ID, but the exact identifier must be verified for the game: [current process identification](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/src/config.cpp).
- The layer must be able to read the Lossless Scaling `lsfg-vk.dll`. The docs warn that Steam’s runtime may hide other partitions; if automatic discovery fails, place the DLL where Steam can see it or set the global `dll` path: [configuration options](https://lsfg-vk.dev/docs/configuration/configuration-options/), [basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/), [current DLL discovery](https://github.com/PancakeTAS/lsfg-vk/blob/develop/lsfg-vk-config/src/config.cpp).
- The official docs do not require a global wrapper command for normal desktop Steam. The `~/lsfg %command%` instruction belongs to the linked unofficial Decky plugin and should not be treated as the NixOS desktop integration contract: [installation guide](https://lsfg-vk.dev/docs/installation/), [unofficial Decky repository](https://github.com/xXJSONDeruloXx/decky-lsfg-vk).

### Flatpak boundary

- A host installation is not enough for Flatpak applications. The Vulkan layer must also be installed into each matching Flatpak runtime, currently documented for Flathub runtimes 24.08 and 25.08; older runtime 23.08 and the UI require a manual/build route: [Flatpak guide](https://lsfg-vk.dev/docs/installation/flatpak/), [source Flatpak guide](https://github.com/PancakeTAS/lsfg-vk/blob/develop/docs/Flatpak-Guide.md).
- Flatpak applications need filesystem access to the LSFG-VK configuration directory and Lossless Scaling installation, plus an `LSFGVK_CONFIG` override. The official example uses `flatpak override`: [Flatpak guide](https://lsfg-vk.dev/docs/installation/flatpak/).
- Treat Flatpak as a separate optional integration. Do not install host manifests into a Flatpak runtime or assume a NixOS host package will bypass Flatpak sandbox permissions.

### Validation and diagnostics

- Run `lsfg-vk-cli validate`; it checks TOML syntax/keys and reports legacy, duplicate, and missing installation files. `lsfg-vk-cli validate -l` lists manually installed files for removal: [validation](https://lsfg-vk.dev/docs/cli/validation/).
- Run `vulkaninfo | grep -i VK_LAYER_LSFGVK_frame_generation` to check loader visibility. Launch a small Vulkan program such as `vkcube` and look for LSFG-VK profile/multiplier/flow/performance log messages; compare with `DISABLE_LSFGVK=1 vkcube`: [getting started](https://lsfg-vk.dev/docs/getting-started/), [basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/).
- For loader diagnostics, use `VK_LOADER_DEBUG=layer`; if the layer appears only when `LSFGVK_ENV=1` is set, profile detection is probably wrong. The guide also recommends checking terminal/log output: [basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/).
- `lsfg-vk-cli benchmark` runs a default 10-second, 1920x1080 generation benchmark. It supports DLL, FP16, size, flow, multiplier, performance-mode, GPU, and duration options; benchmark throughput is a pipeline estimate, not proof of a game’s final displayed FPS: [benchmarking](https://lsfg-vk.dev/docs/cli/benchmark/), [CLI reference](https://lsfg-vk.dev/docs/cli/).
- If frame generation is loaded but ineffective, verify in-game Vsync, try disabling VRR, try `ENABLE_GAMESCOPE_WSI=0` under Gamescope/SteamOS, try windowed mode on Wayland, disable in-game upscalers, and disable other Vulkan layers such as MangoHud/VkBasalt: [basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/).

### Limitations and rollback

- Current limitations include Vulkan-only operation, unreliable/unsupported 32-bit cases, no current dual-GPU support, poor reported dedicated-Intel performance, Vsync/VRR latency and pacing constraints, Steam DLL visibility issues, and interactions with other Vulkan layers: [project overview](https://lsfg-vk.dev/), [basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/), [pacing modes](https://lsfg-vk.dev/docs/configuration/pacing-modes/).
- Steam’s built-in overlay and other performance overlays may report the wrong frame rate because multiple Vulkan layers can be loaded in an unpredictable order: [performance overlays](https://lsfg-vk.dev/docs/troubleshooting/performance-overlays/).
- To disable the layer immediately for a test, set `DISABLE_LSFGVK=1`; to disable a game permanently, remove its launch option or profile match: [environment variables](https://lsfg-vk.dev/docs/configuration/environment-variables/), [getting started](https://lsfg-vk.dev/docs/getting-started/).
- For a manual install, use `lsfg-vk-cli validate -l` and delete the listed v2 files; remove legacy v1 files reported by `validate` to avoid conflicts. If a package manager installed LSFG-VK, uninstall through that package manager instead of manually deleting files: [validation](https://lsfg-vk.dev/docs/cli/validation/).
- The migration note specifically says to uninstall v1 correctly before v2 because the config layout changed: [migration note](https://lsfg-vk.dev/blog/important-changes-to-lsfg-vk/).

## NixOS-specific inferences and implementation plan

The following are implementation recommendations inferred from the upstream facts above; they are not upstream NixOS instructions.

1. Scope the feature to the Linux/NixOS host. Do not add it to a nix-darwin configuration: all upstream installation, Vulkan-layer, Steam, and `/proc` guidance is Linux-oriented.

2. Prefer a pinned source package over unpacking a mutable user archive. Use the official self-hosted repository or an official release archive, pin an exact tag/commit and fixed-output hash, and record the upstream version/commit in the derivation. Do not follow `master`, `develop`, or the auto-build directory implicitly.

3. Build the current v2 layer and CLI with CMake/Ninja. Set the package-manager flag (`LSFGVK_MANAGED=ON`) and set `LSFGVK_LAYER_LIBRARY_PATH` to the final absolute Nix-store path, for example the final `$out/lib/liblsfg-vk-layer.so`. Keep UI support optional and add Qt6/Qt6Quick runtime/build dependencies only when the UI is enabled. This follows the upstream CMake knobs; the exact Nix attribute names must be resolved by the implementing agent.

4. Verify the installed output contains the 64-bit library, the manifest at `$out/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json`, and `lsfg-vk-cli`. Decide explicitly whether the 32-bit layer is built and test it separately; do not claim 32-bit support merely because the 64-bit package builds.

5. Make Vulkan loader discovery a first-class acceptance test. A Nix-store manifest is outside the traditional `/usr` and `~/.local` paths, so the implementation must verify that the active NixOS environment exposes the package’s `share/vulkan/implicit_layer.d` directory to the Vulkan loader. If discovery fails, fix the Nix package/session integration narrowly and confirm with `vulkaninfo`; do not paper over it with an unverified global `LD_PRELOAD` scheme.

6. Do not globally set `LSFGVK_PROFILE`, generation settings, or `LSFGVK_ENV`. Install the layer and CLI globally for the Linux user, but activate a named profile per Steam game with `LSFGVK_PROFILE='Profile name' %command%`, or use `active_in` after confirming the exact Proton executable. Keep diagnostic variables such as `VK_LOADER_DEBUG=layer` and `DISABLE_LSFGVK=1` opt-in.

7. Handle the config mutability decision explicitly. A declarative Nix-managed `conf.toml` is reproducible but the UI cannot freely write it if it is an immutable store symlink; a user-managed config is UI-friendly but less reproducible. Choose one mode, use the current v2 `conf.toml` spelling, and set `LSFGVK_CONFIG` explicitly if the file is not at the default path. Validate the rendered file with `lsfg-vk-cli validate`.

8. Do not hardcode the Lossless Scaling DLL path until it has been tested on the actual Steam installation. First test upstream discovery; if Steam’s runtime hides the path, set `dll`/`LSFGVK_DLL_PATH` to a readable path and keep that path on the same accessible filesystem as the game/runtime.

9. Add focused validation to the implementation handoff:

   - build/evaluate the Nix package and host configuration;
   - run `lsfg-vk-cli validate` and confirm no legacy/duplicate/missing-file warning;
   - run `vulkaninfo | grep -i VK_LAYER_LSFGVK_frame_generation`;
   - run `vkcube` with a matching test profile and compare with `DISABLE_LSFGVK=1 vkcube`;
   - run `lsfg-vk-cli benchmark` once to establish a GPU baseline;
   - launch one native Vulkan application and one Vulkan-through-Proton game with a per-game profile;
   - test the disable path and a Nix generation rollback.

10. Keep rollback simple: remove the package/profile/Steam launch option, verify `DISABLE_LSFGVK=1` works as an emergency switch, and rely on NixOS/Home Manager generation rollback for packaged files. Treat Flatpak runtime layers and Flatpak overrides as separate state that must be removed independently if Flatpak support is later added.

## Source/version cautions for the implementing agent

- The current web page’s `config.toml` path conflicts with the current v2 source and other official examples using `conf.toml`; prefer the source-backed `conf.toml` and verify against the exact release selected.
- Current web docs use both `pacing` and `pacing_mode`; the current parser accepts both, but a generated configuration should use one consistent spelling.
- Old GitHub wiki pages describe v1/older v2 layouts and options. They are useful only for historical migration context; current v2 source and `lsfg-vk.dev` docs take precedence.
- The official project moved its primary source repository from GitHub to `git.lsfg-vk.dev`; pinning should use the current official source/release location and record the exact revision.
