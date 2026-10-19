# Binary cache audit — 2026-10-16

## Recommendations

1. Keep `cache.nixos.org` on both hosts and `nix-community.cachix.org` on Linux.
2. Add `nix-community.cachix.org` on macOS: it has eight exact outputs from the active Darwin package list, including Claude Code, the nix-index wrapper, and Darwin documentation/tools.
3. Add `https://cache.nixos-cuda.org` on Linux: it has our exact CUDA-enabled Sunshine, NVIDIA/CUDA dependencies, and exported `gpu-burn` package. Use the current URL rather than the retired `cuda-maintainers.cachix.org` endpoint.
4. Remove the unused project-specific caches listed below. Treat Codex Desktop separately: its cache is actively published upstream, but the selected computer-use variant has no measured hits.
5. Keep the removed Attic URL **and key** out of the configuration. Its maintainer confirmed a server compromise on October 15. The working Xinux mirror is technically compatible, but should remain a conditional option until its build provenance is established.

This audit adds research artifacts and reusable investigation commands. Cache configuration and the selected kernel are unchanged by this audit.

## Measurements and limits

The inventory covered all 29 direct flake inputs, all 25 package derivation files under `packages/`, both host composition roots, and their active package lists. Linux uses nixpkgs `e7439b6b14ad3cc35d05608ebca9bce01a25f5f8`; Darwin uses `39ad350a0602fa0a58a544344e3e9187526ea45c`.

The active lists contain 300 unique Linux outputs and 116 unique Darwin outputs. Including selected Linux dependency outputs produced **459 distinct store paths**, checked against **12 caches** using 5,508 exact-hash `.narinfo` GET requests. A supplementary CUDA check covered **520 paths**, including additional CUDA/FFmpeg dependencies and the standalone `gpu-burn` output. The evaluated derivation graphs contain 16,477 Linux and 5,533 Darwin derivations; the audit did not query every transitive output against every cache.

Every configured Cachix endpoint returned HTTP 200 for `nix-cache-info`. Their public keys matched the [Cachix API](https://app.cachix.org/api/v1/cache/nix-community). Endpoint health does not establish package coverage. A 404 means that exact store path was absent at the time of the check, not that the cache is empty or cannot help a future pin. One Cachix-client-cache request timed out twice; it remains unknown rather than a confirmed miss.

Measured results and the extra outputs beyond the official cache are preserved in [the JSON evidence](binary-cache-audit-2026-10-16.json). No package contents were downloaded for these probes. Kernel mirror, Sunshine, and `gpu-burn` metadata signatures were separately verified with `nix store verify --no-contents --sigs-needed 1` and the published keys. Signature verification establishes the signer, not reproducibility or absence of compromise.

The separate [upstream-source review](../CACHE_UPSTREAM_RESEARCH.md) records project-owned cache declarations, publishing workflows, keys, and package-selection caveats. The measured results here resolve its intentionally untested coverage questions.

## Cache decisions

All names ending in `.cachix.org` below use HTTPS.

| Cache | Exact hits / 459 | Benefit beyond official cache | Recommendation |
| --- | ---: | --- | --- |
| `cache.nixos.org` | 303 | Baseline: 220 Linux, 72 Darwin, 11 selected dependency outputs | Keep both hosts |
| `nix-community.cachix.org` | 12 | 11 outputs absent from official cache; eight Darwin hits | Keep Linux; add Darwin |
| `cache.xinux.uz` | 227 | Four: CachyOS kernel `out`, `dev`, `modules`, and an NVIDIA EGL wrapper | Conditional; see incident below |
| `codex-desktop-linux.cachix.org` | 0 | None measured for the selected computer-use variant and related outputs | Optional future coverage; not currently paying off |
| `codex-cli.cachix.org` | 0 | Local Codex derivation repackages the official release archive | Remove |
| `ghostty.cachix.org` | 0 | Installed nixpkgs Ghostty and its auxiliary outputs are officially cached | Remove |
| `hyprland.cachix.org` | 0 | No Hyprland compositor derivation in the active Linux graph | Remove |
| `nix-gaming.cachix.org` | 0 | Only its platform sysctl module is enabled; none of its game/Wine packages are used | Remove |
| `noctalia.cachix.org` | 0 | Noctalia remains a locked but inactive alternative | Remove while inactive |
| `vicinae.cachix.org` | 0 | Installed nixpkgs Vicinae is officially cached | Remove |
| `cachix.cachix.org` | 0 | No Cachix client derivation in the active Linux graph; 458 misses and one timeout | Remove |
| `niri.cachix.org` | 0 | Installed `pkgs.niri` 26.04 and its docs are officially cached | Remove duplicate declaration; disable module-added cache |

The CUDA supplement returned 171 hits out of 520 probes, with **14 outputs absent from the official cache**, including Sunshine, `gpu-burn`, NVIDIA userspace outputs, CUDA runtime/compiler components, and their sources. These counts use a larger sample than the table above.

### Niri adds its own cache

Removing the explicit Niri entry from `hosts/pc-fixe/configuration.nix` alone is insufficient. The imported module enables `niri-flake.cache.enable` by default and adds both its URL and public key through `nix.settings.substituters` / `trusted-public-keys`. Its [pinned module implementation](https://github.com/sodiboo/niri-flake/blob/9ee3e13b60643448228353097880521658b2fe0e/flake.nix) exposes the opt-out.

Our `modules/niri.nix` explicitly chooses `pkgs.niri`; the imported overlay exports `niri-stable` and `niri-unstable` and does not replace that attribute. Disabling `niri-flake.cache.enable` therefore fits the current package selection. Reconsider it if switching to a flake-built Niri variant.

### Codex Desktop's variant matters

The [pinned publishing workflow](https://github.com/ilysenko/codex-desktop-linux/blob/1153895b6fe9101fcf777a4264ccaaf3a4ce55be/.github/workflows/cachix.yml) builds the normal desktop and maximal directory/shallow-watch variants. Our configuration selects `codex-desktop-computer-use-ui` and further wraps its CLI path. Neither the underlying selected UI output nor the local wrapper appeared in its cache. Our `nixpkgs.follows` and any downstream overrides can also change output hashes.

Retaining this cache is defensible if future upstream coverage is desired. Its existence and a matching package name do not establish a hit for this configuration.

## Missing URLs and keys

The [official CUDA documentation](https://wiki.nixos.org/wiki/CUDA#Setting_up_CUDA_Binary_Cache) publishes:

```nix
nix.settings.extra-substituters = [ "https://cache.nixos-cuda.org" ];
nix.settings.extra-trusted-public-keys = [
  "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
];
```

Sunshine is explicitly built with `cudaSupport = true` in `modules/sunshine.nix`; `gpu-burn` is exported using a CUDA-enabled package set in `modules/packages.nix`. Both exact outputs are absent from `cache.nixos.org` and present in the CUDA cache. Its `nix-cache-info` advertises priority 50, after the official cache's 40. The old `cuda-maintainers.cachix.org` URL returned HTTP 401.

For Darwin, the [Nix Community cache](https://app.cachix.org/api/v1/cache/nix-community) publishes:

```nix
nix.settings.extra-substituters = [ "https://nix-community.cachix.org" ];
nix.settings.extra-trusted-public-keys = [
  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
];
```

Darwin currently configures only the official cache. Claude Code's cached NAR is approximately 222 MiB unpacked; this figure describes an available artifact, not a measured rebuild-time saving.

## CachyOS incident and mirror

The [maintainer's October 15 statement](https://github.com/xddxdd/nix-cachyos-kernel/issues/110#issuecomment-6189203183) confirms that servers were compromised and the cache/Hydra were shut down during investigation. The maintainer believes the built kernels were not altered; that is not a completed forensic conclusion. The incident concerns this third-party kernel builder, not the CachyOS project generally.

The [pinned README](https://github.com/xddxdd/nix-cachyos-kernel/blob/b1332396df6e880d7e3b6b451c6a74132ce8cf66/README.md#alternative-binary-cache) documents `https://cache.xinux.uz` and key `cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0=`. The mirror serves these exact current outputs, and all three signatures verify against that key:

| Output | Store hash | NAR size, unpacked |
| --- | --- | ---: |
| Kernel | `2cz0axi430ry92dzc11rmkr56ndgph6y` | 27,041,296 bytes |
| Development files | `35c7yplgys54b619l6ag2z76dmqkfv8f` | 778,118,672 bytes |
| Modules | `88s7319zkqq1z6ic7w06hdvbgs7r77mn` | 165,069,920 bytes |

The README describes mirrored builds and explicitly disclaims their security/availability. This audit did not establish independent rebuilding or the artifacts' provenance relative to the incident. A different signature does not establish independence. Keep this as an identified compatible source, rather than automatically adding it as the outage workaround. Building from reviewed sources or using the existing stock-kernel specialisation are alternatives; no kernel change was made here.

## Remaining input and package inventory

| Inputs / sources | Current role | Cache implications |
| --- | --- | --- |
| `nixpkgs`, `nixpkgs-darwin` | Main package sets | Official cache baseline; CUDA overrides need the CUDA cache |
| `flake-parts`, `flake-utils`, `import-tree` | Evaluation libraries | No separate application binary cache needed |
| `nix-darwin`, `home-manager`, `home-manager-darwin` | Host/module composition | Generated host/user configuration builds locally; Nix Community demonstrably covers some exact tools/docs |
| `nix-index-database` | Active command/package index integration | Exact nix-index wrapper hits Nix Community on both hosts; database downloads also use upstream release artifacts |
| `context7-skills`, `mattpocock-skills`, `humanlayer-skills`, `kitlangton-skills` | Source-only skill trees | No compiled application output needing a project cache |
| `screen-capture-toolbar`, `quick-capture`, `dms-plugins` | Source-only plugin assets | Source pinning does not imply a missing application cache |
| `dms`, `dankcalendar`, `dank-greeter` | Active shell, calendar, greeter modules | DMS shell has a local install patch; no additional public cache identified from pinned flake declarations/workflows; guessed `danklinux.cachix.org` returned 401 |
| `jjui`, `herdr`, `tokitoki` | Active upstream-built tools | No dedicated published cache identified in the inspected pinned declarations/workflows; selected outputs miss the tested project caches |
| `code-cursor-nix` | Package expression called with host nixpkgs and compatibility arguments | Upstream release binary is repackaged locally; no dedicated cache identified |
| `spicetify-nix` | Spotify module/assets and customised result | Customised final output can differ from upstream CI; no dedicated missing cache identified |
| `niri`, `noctalia`, `nix-gaming`, `codex-desktop-linux`, `nix-cachyos-kernel` | As detailed above | Package selection and enabled modules determine utility |

All 25 local package recipes were reviewed. Release/archive repackaging covers `agent-browser`, `jj-ryu`, `lightjj`, `cursor-agent`, `codex`, `opencodev2`, `t3code`, `wifi-audio-streaming`, `droidcam-client`, `curseforge`, and `plannotator`. npm/PyPI-backed recipes include `executor`, `opencodex`, `portless`, `update-script-zod`, `arch-ops-server`, and part of `codeburn`. Source builds/local modifications include `crosspipe`, `dankmail`, `gamescope-lanczos`, `lsfg-vk`, `t3code-web`, `t3code-patched`, and vendored `cpuid-fault-emulation`. `vtask` chooses a verified checked-in binary or local source build.

These local derivations do not inherit an upstream cache hit merely by using the same application name. Upstream GitHub/npm/PyPI/CDN downloads and Homebrew bottles/casks are separate distribution mechanisms. No additional application-specific cache was established for these custom recipes; that is not proof that no third-party cache anywhere contains them. A cache publishing this repository's exact outputs would address local custom builds directly.

The pinned nix-index input also has a `garnix.yaml`. Its generic `cache.garnix.io` endpoint failed DNS resolution during this audit, so its output coverage is unknown. It is not a confirmed usable missing cache; the exact nix-index wrapper is already covered by Nix Community.

There is a working `https://herdr.cachix.org` cache for the separate [official Herdr binary-packaging flake](https://github.com/herdrdev/herdr-nix), using key `herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=`. Both current source-built Herdr outputs returned 404 there. Switching packaging could make this cache relevant; adding only the URL would not cache the current Linux or Darwin app output.

## Validation and application boundary

The existing Linux configuration evaluated successfully, and its dry run completed with 46 local derivations and six fetched paths on the current machine. That dry run is not evidence of a fresh-machine cache closure: most packages already exist locally. The daemon ignored the untrusted Xinux command-line addition, so mirror support is established by the direct metadata/signature checks, not that dry run.

The proposed reduced policy was separately evaluated with temporary `extendModules` overrides on both hosts. Linux retained the official cache plus Nix Community and CUDA, disabled the automatic Niri cache, and excluded Xinux; Darwin retained the official cache plus Nix Community. Both complete host derivations evaluated successfully. These temporary evaluations did not edit or activate the host configuration.

New cache URLs/keys must be applied by the privileged Nix daemon before ordinary rebuilds can use them. Keep official-cache signature verification enabled. The prior instruction for replacing the cache list during the first privileged rebuild remains in `INVESTIGATION_COMMANDS.md`.
