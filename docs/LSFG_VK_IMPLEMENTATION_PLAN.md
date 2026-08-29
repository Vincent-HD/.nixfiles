# LSFG-VK implementation plan

## Objective

Add LSFG-VK to the `pc-fixe` NixOS gaming setup so that:

- the Vulkan implicit layer is available to native applications and Steam/Proton games;
- `lsfg-vk-ui` and `lsfg-vk-cli` are available in the desktop session;
- the package is reproducibly pinned and maintainable through this repository's update workflow;
- per-game profiles remain editable through the upstream UI;
- installation, rollback, and runtime validation are documented.

This is an implementation handoff. It does not install or configure LSFG-VK yet.

## Selected version track

Implement the **v2 release-candidate line described by the linked documentation**, not the stable
`pkgs.lsfg-vk` and `pkgs.lsfg-vk-ui` packages currently in the locked nixpkgs.

The locked nixpkgs packages are version 1.0.0, while the current documentation explicitly targets
v2 and documents the v2 CLI, profile model, and `lsfg-vk.dll` integration. Upstream has moved its
authoritative repository away from the now-stale GitHub mirror. At the time of planning, the
official repository's newest tag is `2.0.0-rc1`; its annotated tag resolves to immutable commit
`f715073ee39377fbe2bd856db01b458b920b126e`. Pin that commit and record `2.0.0-rc1` as the package
version.

If the user later prefers stability over the linked v2 feature set, the smaller alternative is to
install nixpkgs' 1.0.0 `lsfg-vk` and `lsfg-vk-ui` packages. Do not combine those v1 packages with
the v2 instructions below.

Sources:

- [Upstream installation documentation](https://lsfg-vk.dev/docs/installation/)
- [Upstream build options](https://lsfg-vk.dev/docs/installation/building-from-source/)
- [Official source repository](https://git.lsfg-vk.dev/lsfg-vk/)
- [Upstream migration note](https://lsfg-vk.dev/blog/important-changes-to-lsfg-vk/)

## Repository integration map

| File | Planned responsibility |
| --- | --- |
| `packages/lsfg-vk/default.nix` | Build the pinned v2 layer, CLI, UI, desktop file, and icon from source. |
| `packages/lsfg-vk/update.ts` | Resolve official v2 release/RC tags, annotated-tag commits, and source hashes. |
| `modules/packages.nix` | Expose `packages.x86_64-linux.lsfg-vk` for direct builds and update automation. |
| `modules/lsfg-vk.nix` | Add the package to the host profile and Steam FHS environment without managing mutable profiles. |
| `hosts/pc-fixe/default.nix` | Compose `nixos.lsfgVk` into the Linux host only. |
| `scripts/update-pins.json` | Register the package's supported update command. |
| `docs/UPDATE_COMMANDS.md` | Document the pin, update command, and required post-update checks. |
| `README.md` | Add the feature to the gaming/module overview if that overview is kept exhaustive. |

Do not add a flake input. This is an application package, and the repository convention is a
standalone derivation under `packages/` exposed as a flake package.

## Implementation phases

### 1. Package the pinned v2 source

Create `packages/lsfg-vk/default.nix` using `llvmPackages.stdenv.mkDerivation (finalAttrs: { ... })` and
`fetchgit` with:

- URL `https://git.lsfg-vk.dev/lsfg-vk.git`;
- version `2.0.0-rc1` and immutable revision
  `f715073ee39377fbe2bd856db01b458b920b126e`;
- no submodule fetch unless a future pinned revision adds `.gitmodules`;
- Linux-only metadata, `lib.licenses."cc-by-nc-nd-40"`, the official homepage/source URL, and
  `lsfg-vk-ui` as the main
  desktop program.

The v2 source is CC BY-NC-ND 4.0 and therefore non-free in nixpkgs terms. The host already permits
unfree software, but the generic `perSystem` package set does not. Expose the flake package through
the existing `unfreePkgs` package set in `modules/packages.nix`, as this repository already does
for other non-free outputs. Do not upload the resulting package to a public or commercial binary
cache; this integration is for the user's local system. Prefer CMake's supported configuration
flags over source patches.

Build with Clang, CMake, and Ninja. Use the dependencies required by the pinned source rather than
copying distribution package names from the generic guide. The expected Nix inputs are CMake,
Ninja, Vulkan headers, Qt 6 declarative, and the Qt wrapping hook. Confirm the exact set by building
with strict dependencies.

Enable all user-facing components with CMake:

```text
LSFGVK_BUILD_LAYER=ON
LSFGVK_BUILD_CLI=ON
LSFGVK_BUILD_UI=ON
LSFGVK_INSTALL_LIBRARIES=OFF
LSFGVK_MANAGED=ON
LSFGVK_LAYER_MULTILIB_X86=OFF
```

Do not pass documentation-only options blindly. In particular, verify every flag against the
pinned commit's `CMakeLists.txt`; the current source and website have changed names across v2
iterations.

Make the generated implicit-layer manifest point directly to the store library, for example by
setting `LSFGVK_LAYER_LIBRARY_PATH` to the final output's
`lib/liblsfg-vk-layer.so` or patching the installed JSON during fixup. A bare library filename is
not reliable in Nix or inside Steam's FHS container. Confirm the final JSON contains an absolute
store path and is installed under `share/vulkan/implicit_layer.d/`.

Ensure `lsfg-vk-ui` is Qt-wrapped and that these installed artifacts exist:

```text
bin/lsfg-vk-cli
bin/lsfg-vk-ui
lib/liblsfg-vk-layer.so
share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json
share/applications/gay.pancake.lsfg-vk-ui.desktop
share/icons/hicolor/256x256/apps/gay.pancake.lsfg-vk-ui.png
```

The v2 manifest declares an implicit layer. Khronos documents that implicit manifests are found
under each XDG data directory's `vulkan/implicit_layer.d` suffix and are enabled automatically
unless their disable environment is set. Therefore, use normal package/profile composition; do
not set global `VK_LAYER_PATH` or `VK_IMPLICIT_LAYER_PATH` variables.

Source: [Khronos Vulkan loader layer discovery](https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderLayerInterface.md#linux-layer-discovery)

### 2. Expose the package and integrate it with the gaming host

In `modules/packages.nix`, expose the derivation as Linux-only
`packages.x86_64-linux.lsfg-vk` through `unfreePkgs.callPackage` (using the existing host-platform
conditional style).

Create a focused dendritic module in `modules/lsfg-vk.nix`:

1. Call the local package with `pkgs.callPackage ../packages/lsfg-vk { }` so the module and flake
   output use the same derivation definition.
2. Add it to `environment.systemPackages`. This provides the CLI/UI, desktop entry, host-side
   manifest, and native Vulkan integration.
3. Add it and `pkgs.vulkan-tools` to `programs.steam.extraPackages`. The NixOS Steam module places
   these packages inside Steam's FHS environment, which is where Proton-launched Vulkan processes
   must see the manifest and where the documented `steam-run vulkaninfo` check needs its executable.
4. Add `pkgs.vulkan-tools` to `environment.systemPackages` if it is not already present, because
   upstream uses `vulkaninfo` and `vkcube` for discovery and activation checks.
5. Do not set `LSFGVK_PROFILE`, `LSFGVK_CONFIG`, `LSFGVK_ENV`, or `DISABLE_LSFGVK` globally.

Compose `nixos.lsfgVk` in `hosts/pc-fixe/default.nix` next to `nixos.gaming`. Do not add it to the
Darwin host and do not fold it into `modules/graphics.nix`; LSFG-VK is an optional gaming feature,
not an NVIDIA driver requirement.

### 3. Keep profiles mutable

Do not create a Home Manager-owned `~/.config/lsfg-vk/conf.toml` in the initial implementation.
The upstream UI creates and hot-reloads this file, and game/executable associations are user state.
Managing it declaratively would either prevent UI edits or create activation conflicts.

After activation, the user will:

1. Own and install **Lossless Scaling** through Steam.
2. Select its `lsfg-vk` beta branch as required by the v2 installation guide.
3. Start `lsfg-vk-ui` and point it at `lsfg-vk.dll` only if auto-discovery does not find the Steam
   installation.
4. Create a profile, select multiplier/flow scale/performance mode, and add the correct game
   executable under **Active In**.
5. Enable VSync in the game when using the documented VSync pacing mode.

Lossless Scaling itself cannot be installed declaratively by this repository: it is a separately
licensed Steam product. The configuration should only package the open-source Vulkan layer.

Sources:

- [Getting started and profile activation](https://lsfg-vk.dev/docs/getting-started/)
- [Configuration options](https://lsfg-vk.dev/docs/configuration/configuration-options/)
- [Environment variables](https://lsfg-vk.dev/docs/configuration/environment-variables/)

### 4. Maintain the upstream pin

Keep the derivation `nix-update` compatible: use one version field, one immutable `fetchgit`
revision, and one source hash. The package-specific `packages/lsfg-vk/update.ts` updater is needed
because the official forge exposes annotated tags outside GitHub's release API. It must discover
stable/RC v2 tags, resolve the peeled commit for annotated tags, prefetch the source hash, and
update version, revision, and hash together while rejecting development branches.

Register the package in `scripts/update-pins.json` as an x86_64-linux `nix-update` entry using
`--use-update-script`, and document the exact command and verification sequence in
`docs/UPDATE_COMMANDS.md`. Every update must review the upstream license, CMake option names,
manifest name, configuration schema, and DLL filename before accepting the new build.

### 5. Build-time verification

Run focused checks before any system activation:

```bash
nix build .#lsfg-vk --no-link
nix eval .#nixosConfigurations.pc-fixe.config.system.build.toplevel.drvPath --raw
nix build .#nixosConfigurations.pc-fixe.config.system.build.toplevel --no-link
nix fmt -- --ci
nix flake check
```

Also inspect the built output rather than assuming CMake installed every enabled component:

```bash
PACKAGE=$(nix build .#lsfg-vk --no-link --print-out-paths)
   find "$PACKAGE" -maxdepth 5 \( -type f -o -type l \)
cat "$PACKAGE/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json"
```

The implementation is not complete if the manifest uses only `liblsfg-vk-layer.so`, if the UI is
missing its Qt runtime, or if the desktop entry points to a command absent from `bin/`.

### 6. Runtime acceptance test

After `sudo nixos-rebuild test --flake .#pc-fixe`:

1. Confirm host discovery:

   ```bash
   vulkaninfo | rg 'VK_LAYER_LSFGVK_frame_generation'
   lsfg-vk-cli validate
   ```

2. Confirm Steam-runtime discovery separately:

   ```bash
   steam-run vulkaninfo | rg 'VK_LAYER_LSFGVK_frame_generation'
   ```

3. Launch `lsfg-vk-ui`, create a temporary profile for `vkcube`, then run `vkcube`. Success means
   LSFG-VK logs the selected profile and the cube's motion changes.
4. Compare with `DISABLE_LSFGVK=1 vkcube`; the layer should be absent and normal rendering should
   return.
5. Test one Proton game with VSync enabled and either an **Active In** executable match or the Steam
   launch option `LSFGVK_PROFILE='profile name' %command%`.
6. Check that MangoHud and Gamescope still work. Do not add special Gamescope integration in this
   change; upstream tracks known Gamescope frame-pacing interactions, so basic coexistence is the
   correct initial scope.

If discovery fails, rerun with `VK_LOADER_DEBUG=layer` and inspect which implicit manifest paths
the host and `steam-run` search. Do not work around a packaging error by adding a global layer-path
environment variable until the manifest and Steam package composition have been checked.

Sources:

- [Upstream validation workflow](https://lsfg-vk.dev/docs/cli/validation/)
- [Upstream basic troubleshooting](https://lsfg-vk.dev/docs/troubleshooting/basic-troubleshooting-steps/)
- [Khronos Vulkan loader debugging](https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderDebugging.md)

## Rollback and failure boundaries

- Before activation, failure is isolated to the new package build or host evaluation.
- `nixos-rebuild test` permits rebooting back to the existing generation before a permanent
  `switch`.
- Removing `nixos.lsfgVk` from `hosts/pc-fixe/default.nix` removes the package and layer from the
  next generation.
- `DISABLE_LSFGVK=1` is the per-process emergency bypass documented by upstream.
- Keep `~/.config/lsfg-vk/conf.toml` on rollback unless the user explicitly wants profile data
  deleted; it is mutable user data and is not owned by Nix.
- Do not delete the separately purchased Lossless Scaling Steam installation as part of Nix
  rollback.

## Definition of done

- `.#lsfg-vk` builds reproducibly from an immutable v2 commit.
- The manifest contains an absolute Nix store path and the expected implicit-layer name.
- The package is visible in both the system profile and Steam FHS environment.
- `lsfg-vk-ui`, `lsfg-vk-cli`, `vulkaninfo`, and `vkcube` are available after activation.
- Host and `steam-run` both enumerate `VK_LAYER_LSFGVK_frame_generation`.
- `lsfg-vk-cli validate` reports no missing package-managed files.
- A `vkcube` profile activates, and `DISABLE_LSFGVK=1` bypasses it.
- One Proton game activates a profile without regressing MangoHud or Gamescope.
- The update registry and `docs/UPDATE_COMMANDS.md` cover future v2 prerelease bumps.
- Linux host evaluation, formatting, and repository checks pass.

## Explicit non-goals

- Installing or licensing Lossless Scaling through Steam.
- Managing game-specific profiles declaratively in the first change.
- Flatpak Vulkan-layer installation; the current Steam package is native NixOS.
- Adding a 32-bit LSFG-VK layer unless a concrete native 32-bit Vulkan application requires it.
- Changing NVIDIA, Gamescope, Niri, kernel, or gaming-optimization settings.
