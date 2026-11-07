# Audit of locally compiled software and prebuilt binaries

Audit date: November 5, 2026. Scope: the active `pc-fixe` (x86_64-linux) and `macbook-pro` (aarch64-darwin) configurations, custom flake packages, `flake.lock`, `scripts/update-pins.json`, and `docs/UPDATE_COMMANDS.md`.

**Subsequent changes:** DMS and LSFG-VK now use prebuilt upstream releases. Inspection confirmed that the LSFG-VK archive includes the i686 layer as well. The measurements below describe the configuration at the time of the audit.

## Findings and priorities

| Package | Observation at audit time | Recommendation |
| --- | --- | --- |
| DMS | Built locally from Go; output approximately 86 MiB; the exact output was absent from configured caches. The official v2.0.0 Linux release matches the locked commit. | Test the release archive with Nix, including QML, services, and Niri integration; update the archive, commit, and hashes together. This was subsequently implemented. |
| LSFG-VK | Built with CMake, Ninja, Clang, and Qt; outputs approximately 2.5 MiB and 1.0 MiB. An upstream Linux archive exists, under CC BY-NC-ND 4.0. | Check redistribution terms, ABI compatibility, Vulkan registration, and both architectures. Archive inspection subsequently confirmed i686 support and the prebuilt package was implemented. |
| vtask | Checked-in x86_64 Linux and arm64 macOS binaries were rejected because the recorded Bun version was 1.4.2 while the pinned nixpkgs supplied 1.4.4. The measured Linux Bun build took 2.41 seconds. | Low priority: if needed, regenerate both binaries and their manifest together using the expected Bun version. |
| Gamescope-Lanczos, Crosspipe, Dankmail, CPUID Fault Emulation | No suitable upstream binary was identified, or the package depends on the running kernel ABI. | Keep their Nix builds. |
| Niri, Ghostty, Quickshell, LocalSend, Deskflow | The exact outputs checked were available from `cache.nixos.org`. | Keep Nix packages and use the binary cache. |

## Method and limitations

Active modules were traced from the [Linux](../../hosts/pc-fixe/default.nix) and [macOS](../../hosts/macbook-pro/default.nix) host compositions and cross-checked against package definitions and [flake exports](../../modules/packages.nix). Flake outputs not installed by those hosts were not treated as active software.

A path in `/nix/store` alone does not show whether it was built locally or downloaded. Retained logs confirm local builds for DMS, LSFG-VK, Gamescope-Lanczos, Crosspipe, vtask, and Deskflow; they do not prove the provenance of every current installation. A cache hit establishes that the exact output was substitutable at audit time, not how it was previously installed. Output sizes do not necessarily include shared dependencies or temporary build space.

The audit was read-only. It did not perform large builds, runtime tests, signature verification, or a system rebuild. It did not have access to the active Nix store on the Mac. Apart from the vtask measurement, comparable build durations were unavailable, so estimated time savings were not established.

## Detailed findings

### DMS

The locked `dms` input pointed to commit `9b413296b16721f7679fb62e624cb1ed2433fa58`, matching [official release v2.0.0](https://github.com/duxlabs-dev/dux-shell/releases/tag/v2.0.0). Its Linux archives include the CLI, QML sources, completions, and installation files:

- `dms-full-amd64.tar.gz`: 78,835,007 bytes, SHA-256 `a28056dbf8746178f6a6b0796077023705becb6037c418311132bda579bdd185`.
- `dms-full-arm64.tar.gz`: 75,999,571 bytes, SHA-256 `55df869f02c58eafacdfff8dd66c86b35b1e7918f4cf0b777533a5761d3fde92`.

The upstream license is MIT. Official checksum files were available; independent signatures or attestations were not confirmed. The compressed archive is approximately 75 MiB, so disk savings were not established. The anticipated benefit was avoiding the uncached Go build. A prebuilt integration must preserve QML layout, executables, systemd services, Niri integration, and plugin paths, while updating source commit, release version, artifacts, and hashes together.

### LSFG-VK

The [official installation documentation](https://lsfg-vk.dev/docs/installation/) listed `lsfg-vk-2.0.0.tar.xz`, matching the package version. Upstream describes Ubuntu 22.04-based builds and requires Qt 6 for the interface. Its [license documentation](https://lsfg-vk.dev/docs/contributing/) specifies CC BY-NC-ND 4.0. The original audit could not establish archive architecture coverage, signatures, checksums, or ABI compatibility from the website alone. Subsequent archive inspection confirmed the i686 layer, and the setup now uses the prebuilt release. Linux Vulkan registration and Qt dependencies remain relevant to validation.

### Other packages

- **Gamescope-Lanczos:** C++/Vulkan, Meson, submodules, and local patches; approximately 7.2 MiB plus 1.1 MiB for 32-bit WSI. The [fork releases](https://github.com/ThomasEricB/gamescope-lanczos-downscaling/releases) offered source archives only. The fork's Lanczos and NVIDIA changes make ordinary `pkgs.gamescope` an incomplete replacement.
- **Crosspipe:** Vala/Meson, GTK 4, libadwaita, and PipeWire; approximately 328 KiB. Its [upstream](https://github.com/pinpox/Crosspipe/releases) had no releases at audit time.
- **Dankmail:** Go and Quickshell with a local test patch; approximately 50 MiB. No suitable binary was found on its [release page](https://github.com/arqueon/dankmail/releases).
- **CPUID Fault Emulation:** kernel module built against the exact active kernel; a generic prebuilt module is unsuitable.
- **LocalSend:** Linux 1.18.0 was cached; macOS already used an upstream DMG. The [1.18.2 release](https://github.com/localsend/localsend/releases/tag/v1.18.2) included Linux artifacts and a security fix for peer-supplied HTTP redirects; updating nixpkgs to a corrected version was recommended.
- **Deskflow:** the approximately 4.7 MiB Linux output was cached despite an older local build log. macOS already used the upstream Homebrew cask. Upstream Linux binaries were not verified as direct NixOS substitutes.
- **Ghostty:** the Linux package was cached; upstream distributes official prebuilt binaries for macOS and relies on distributions for Linux binaries. See [upstream documentation](https://ghostty.org/docs/install/binary).
- **Handy:** the custom package already used official 0.10.0 Linux AppImage and macOS tarball releases, with both hashes updated together. The published artifacts were 123,783,672 and 14,931,538 bytes; the extracted Linux AppImage occupied approximately 378 MiB, illustrating that prebuilt distribution does not necessarily save disk space.
- **Other prebuilt applications:** Codex, Cursor Agent, Executor, Plannotator, T3Code, WiFi Audio Streaming, CurseForge, Portless, `jj-ryu`, `lightjj`, and `opencodev2` already use published artifacts. Large vendor payloads such as OnlyOffice do not imply local compilation.

## Updates and provenance

Keep platform-specific artifacts and hashes synchronized in one update, regardless of the machine running the updater. Prefer official upstream releases and Nix-pinned hashes, and check signatures where available. A checksum detects changed content but is not an independent signature. See the [update registry](../../scripts/update-pins.json) and [update guide](../UPDATE_COMMANDS.md).
