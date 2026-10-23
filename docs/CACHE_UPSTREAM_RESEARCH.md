# Upstream binary-cache research

See the [measured cache audit](research/binary-cache-audit-2026-10-16.md) for exact-path results, CUDA coverage, and the confirmed CachyOS-builder incident. The recommendations there incorporate this upstream-source review.

**Snapshot:** 2026-10-16. This compares the locked flake inputs and host wiring in [flake.nix](../flake.nix), [flake.lock](../flake.lock), [pc-fixe](../hosts/pc-fixe/default.nix), [macbook-pro](../hosts/macbook-pro/default.nix), and their Nix settings. Upstream links point to project-owned documentation, flakes, CI, or cache pages. “No cache found” means none was advertised in the upstream sources checked; it does not rule out third-party caches. Exact store-path hits and live endpoint checks are left to the parent audit.

## Findings

- The Linux host has ten extra Cachix substituters; macOS has no extra substituters configured. Nix already defaults to `https://cache.nixos.org`, so that default does not need to be repeated in `extra-substituters`. See [Linux settings](../hosts/pc-fixe/configuration.nix), [macOS settings](../hosts/macbook-pro/configuration.nix), and the [Nix substituters reference](https://nix.dev/manual/nix/2.30/command-ref/conf-file.html#conf-substituters).
- The configured `codex-desktop-linux` pair is the right upstream URL and key for the active Codex Desktop flake output. Whether its exact path is present still depends on the selected package variant and the locked inputs.
- `hyprland`, `cachix`, and (for normal host builds) `noctalia` have no active package output to serve. Several other configured caches are for flakes whose package outputs this config does not select; those are likely redundant for the relevant app, but exact-path checks decide whether they serve shared dependencies.
- I found no project cache URL/key advertised by the locked upstream sources for DMS, DankCalendar, dank-greeter, JJUI, Cursor, Spicetify, the source-built Herdr flake, or Tokitoki. The separate official `herdr-nix` cache packages prebuilt release binaries and therefore does not match the current source-built Herdr derivation.
- The upstream CachyOS-kernel flake still carries its maintainer’s Attic URL in the locked `flake.nix`; that URL is absent from this config. The project README also documents a third-party mirror, while explicitly disclaiming responsibility for its security and availability.

## Configured cache pairs and fit

Every key below is already present in [the Linux host’s settings](../hosts/pc-fixe/configuration.nix). Keys are included here to record the upstream identity and intended coverage, not to recommend blindly trusting any cache.

| Cache | Upstream URL and public key | Fit for this flake |
| --- | --- | --- |
| Codex Desktop | `https://codex-desktop-linux.cachix.org`<br>`codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk=` ([pinned upstream flake](https://github.com/ilysenko/codex-desktop-linux/blob/1153895b6fe9101fcf777a4264ccaaf3a4ce55be/flake.nix)) | **Relevant.** Linux selects `codex-desktop-computer-use-ui` from this flake in [modules/agents/codex.nix](../modules/agents/codex.nix). Root `nixpkgs.follows` and the feature-specific output can change the derivation path from upstream CI’s path; verify that exact output. |
| Codex CLI | `https://codex-cli.cachix.org`<br>`codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing=` ([Cachix page](https://app.cachix.org/cache/codex-cli), [cache owner’s README](https://github.com/sadjow/codex-cli-nix)) | **Likely mismatch.** This cache belongs to `sadjow/codex-cli-nix`; the repo instead builds a local package from OpenAI’s release archive with a wrapper and companion executable ([packages/codex](../packages/codex/default.nix)). It is not the same declared flake input or package expression. |
| Ghostty | `https://ghostty.cachix.org`<br>`ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns=` ([upstream flake](https://github.com/ghostty-org/ghostty/blob/main/flake.nix)) | **Unproven / likely redundant for the app.** Linux uses `pkgs.ghostty`; macOS uses Homebrew ([module](../modules/ghostty.nix)). The config does not consume Ghostty’s flake package output, so its cache’s exact app path is not assured. |
| Hyprland | `https://hyprland.cachix.org`<br>`hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=` ([Hyprland Cachix docs](https://wiki.hypr.land/Nix/Cachix/), [Cachix page](https://app.cachix.org/cache/hyprland)) | **No active use.** Upstream says the cache applies to the Hyprland flake package and can be skipped for the Nixpkgs package. Neither host imports Hyprland; the only related `hyprpicker` reference is in inactive Noctalia plugin dependencies. |
| nix-gaming | `https://nix-gaming.cachix.org`<br>`nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=` ([pinned flake](https://github.com/fufexan/nix-gaming/blob/48295cadfae0d3c9b98ec0c987437d4628f8202e/flake.nix), [README](https://github.com/fufexan/nix-gaming/tree/48295cadfae0d3c9b98ec0c987437d4628f8202e#install--run)) | **Correct pair; little expected package coverage.** The host imports only `nixosModules.platformOptimizations`; it does not use nix-gaming’s optional game/Wine packages ([module](../modules/gaming-optimization.nix)). The README identifies Wine as a main cache use. The “little direct benefit” assessment is an inference from this module-only use. |
| Noctalia | `https://noctalia.cachix.org`<br>`noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=` ([upstream NixOS/cache docs](https://github.com/noctalia-dev/noctalia-docs/blob/main/src/content/docs/noctalia/getting-started/nixos.mdx), [Cachix page](https://app.cachix.org/cache/noctalia)) | **Inactive for host toplevels; cache caveat if reused.** No host imports Noctalia; [modules/checks.nix](../modules/checks.nix) has a separate Noctalia check. The locked input is the older `noctalia-shell` v4 revision and sets `nixpkgs.follows = "nixpkgs"`. Current docs say following/overriding nixpkgs changes the derivation hash and advise the `cachix` branch for already-cached commits. |
| Vicinae | `https://vicinae.cachix.org`<br>`vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=` ([upstream NixOS docs](https://docs.vicinae.com/nixos)) | **Likely redundant for the selected package.** Upstream says this Cachix cache is for its flake and warns `nixpkgs.follows` will make it miss; it separately documents `pkgs.vicinae` as the Nixpkgs/Hydra alternative. This repo selects `pkgs.vicinae`, not the Vicinae flake ([module](../modules/vicinae.nix)). |
| nix-community | `https://nix-community.cachix.org`<br>`nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=` ([nix-community infra flake](https://github.com/nix-community/infra/blob/master/flake.nix)) | **Potentially useful, not proven for a selected output.** This is a broad community builder cache, not a blanket cache for every `nix-community` input. The active `nix-index-database` module does not by itself establish that its chosen store paths are published there. |
| Cachix CLI | `https://cachix.cachix.org`<br>`cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM=` ([Cachix project README](https://github.com/cachix/cachix)) | **No active package use found.** This is Cachix’s own CLI cache; the host configures caches but does not install the `cachix` CLI package. |
| Niri | `https://niri.cachix.org`<br>`niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=` ([Niri README](https://github.com/sodiboo/niri-flake#binary-cache), [Cachix page](https://app.cachix.org/cache/niri)) | **Cache is real, selected compositor is different.** Upstream says it contains the flake’s `niri-stable`/`niri-unstable` outputs for x86_64-linux. This host explicitly sets `programs.niri.package = pkgs.niri` because the flake package fails against the locked nixpkgs revision ([module](../modules/niri.nix)). The flake overlay/module remain imported, but the compositor binary comes from Nixpkgs. |

The upstream README/flake pins for Niri and the cache pair agree on platform scope: this x86_64 Linux host is supported; macOS is not. The **nix-community** cache is the only configured entry for which this review did not find a reason to call it useless, but actual hits still require an exact path.

## Missing or nonmatching upstream caches

### No dedicated cache advertised in the locked project sources

The following checked upstream flakes/READMEs do not advertise a dedicated substituter and signing key. Keep `cache.nixos.org` as the generic default; do not invent project cache URLs or keys.

| Input / package source | Locked upstream source | Local use / caveat |
| --- | --- | --- |
| DankMaterialShell | [flake at locked revision](https://github.com/AvengeMedia/DankMaterialShell/blob/4a87e8227daf0840b3376fd5e7f891f5900165a6/flake.nix), [Nix CI](https://github.com/AvengeMedia/DankMaterialShell/blob/master/.github/workflows/nix-pr-check.yml) | Active Linux system and HM modules. Local `dms-shell` applies `overrideAttrs` with a QML patch, so even an upstream cache for the unmodified package would not match the final DMS derivation ([module](../modules/dms/dms.nix)). |
| DankCalendar | [flake at locked revision](https://github.com/AvengeMedia/dankcalendar/blob/a97ba89154190bfcea995486aa4a9b80143d2432/flake.nix), [Nix CI](https://github.com/AvengeMedia/dankcalendar/blob/master/.github/workflows/nix-pr-check.yml) | Active through the DMS Home Manager module. No upstream cache URL/key found in the reviewed flake or Nix CI. |
| dank-greeter | [flake at locked revision](https://github.com/AvengeMedia/dank-greeter/blob/c28d7b1c1e7e3e82cb9594076f60a21993d5a742/flake.nix), [Nix CI](https://github.com/AvengeMedia/dank-greeter/blob/master/.github/workflows/nix-pr-check.yml) | Active NixOS greeter module from [modules/niri.nix](../modules/niri.nix). No upstream cache URL/key found in the reviewed flake or Nix CI. |
| JJUI | [flake at locked revision](https://github.com/idursun/jjui/blob/151c7c51bf5b2cf49ea9ccdcde8ef98538f59787/flake.nix), [README](https://github.com/idursun/jjui/blob/151c7c51bf5b2cf49ea9ccdcde8ef98538f59787/README.md) | Active as `inputs.jjui.packages.<system>.jjui` ([Jujutsu module](../modules/coding/jujutsu.nix)); no project cache declaration found. |
| Cursor (`code-cursor-nix`) | [flake at locked revision](https://github.com/jacopone/code-cursor-nix/blob/b18dc779dc79099428d943e25279e632bdaed1fd/flake.nix), [README](https://github.com/jacopone/code-cursor-nix/blob/b18dc779dc79099428d943e25279e632bdaed1fd/README.md) | Active on both hosts. The repo calls the upstream `package.nix` with local `pkgs`, rather than consuming the upstream flake package output ([editors module](../modules/coding/editors.nix)); no upstream cache declaration found. |
| Spicetify | [flake at locked revision](https://github.com/Gerg-L/spicetify-nix/blob/32d97b6b3c3401e5d0e474c82e764f8f9bf35b86/flake.nix), [README](https://github.com/Gerg-L/spicetify-nix/tree/32d97b6b3c3401e5d0e474c82e764f8f9bf35b86) | Active on Linux via its HM module and legacy packages ([Spotify module](../modules/spotify.nix)); no project substituter/key found in the locked flake/README. |
| Herdr source flake | [flake at locked revision](https://github.com/ogulcancelik/herdr/blob/299dd4163a96381ec2d8e5bde13d7ba6d6432373/flake.nix), [README](https://github.com/ogulcancelik/herdr/blob/299dd4163a96381ec2d8e5bde13d7ba6d6432373/README.md) | Active `inputs.herdr.packages.<system>.default` ([CLI module](../modules/command-line/default.nix)); its locked flake builds the source package and has no cache declaration. |
| Tokitoki | [flake at locked revision](https://github.com/astahmer/tokitoki/blob/99245f7fbd8bf6f693a5a306e04c0f81f3baf0d6/flake.nix), [README](https://github.com/astahmer/tokitoki/blob/99245f7fbd8bf6f693a5a306e04c0f81f3baf0d6/README.md) | Active on Linux and macOS ([module](../modules/tokitoki.nix)); no project cache declaration found in the locked flake/README. |

The project-owned Nix PR-check workflows for the three AvengeMedia flakes run Nix checks/builds but do not configure a dedicated substituter; their upstream flakes also do not declare one. These findings mean “no upstream cache advertised in the reviewed sources,” not “third-party caches cannot exist.”

### Upstream cache exists, but it is another Herdr derivation

Herdr’s own packaging repository, [`herdr-nix`](https://github.com/herdrdev/herdr-nix), publishes a public cache:

- URL: `https://herdr.cachix.org`
- Key: `herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=`

The README identifies it as official packaging for Herdr’s prebuilt GitHub Release binaries. The current config instead imports the source-build flake `ogulcancelik/herdr`; the packaging repo is a separate flake and derivation. Adding this URL/key alone does not make the current `inputs.herdr` output substitutable.

## CachyOS kernel cache caveat

The pinned [`nix-cachyos-kernel` flake](https://github.com/xddxdd/nix-cachyos-kernel/blob/b1332396df6e880d7e3b6b451c6a74132ce8cf66/flake.nix) still declares `https://attic.xuyh0120.win/lantian` with key `lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=`. That is the removed/unreachable Attic endpoint, so it is not a usable cache recommendation.

The upstream [release README](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/README.md#alternative-binary-cache) lists an alternative mirror:

- URL: `https://cache.xinux.uz`
- Key: `cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0=`

Live probe on 2026-10-23: the original Attic endpoint returned HTTP 503 with an
explicit server-compromise notice. The maintainer [reported the shutdown on
October 15](https://github.com/xddxdd/nix-cachyos-kernel/issues/110#issuecomment-6189203183).
Their [October 21 update](https://github.com/xddxdd/nix-cachyos-kernel/issues/110#issuecomment-6310662239)
says Hydra is restored, but the binary cache remains offline pending monitoring
and will return under a new URL and signing key. They found no apparent data
modifications; this is the maintainer's assessment, not independent verification.
The mirror
served matching narinfo for all three outputs of the pinned
`linux-cachyos-latest-x86_64-v3-7.2.8` derivation (`out`, `dev`, and `modules`).
Their metadata signatures verified against the documented mirror key, and ranged
GET requests to their advertised NAR URLs succeeded. HEAD requests returned 404,
so HEAD alone gives a false miss for this gateway. The active local substituter
and trusted-key lists contain neither this mirror nor the original Attic cache.
Signature verification establishes the mirror's signer, not independent evidence
that its artifacts were rebuilt outside the compromised infrastructure. Its
operator [advertises a separate Hydra build service](https://github.com/xddxdd/nix-cachyos-kernel/issues/89),
but the exact outputs' build provenance was not checked here.

The CachyOS-kernel maintainer explicitly says they cannot guarantee the mirror’s security or availability. Treat it as a third-party option requiring separate trust and endpoint checks. The project documents its own cache as tied to an exact nixpkgs revision and demonstrates `overlays.pinned`; this repo deliberately does **not** set `inputs.nix-cachyos-kernel.inputs.nixpkgs.follows` and uses that pinned overlay ([root input](../flake.nix), [kernel module](../modules/gaming-optimization.nix)). This is the important exception to the repo’s normal `follows = "nixpkgs"` convention.

## Pinning and configuration implications

1. A cache only substitutes a store path with the same derivation hash. A correct URL/key does not guarantee a hit when the package expression, platform, selected output, or dependency graph differs. This is why the cache for a flake output should not be assumed to cover a Nixpkgs package of the same name.
2. `follows` redirects an input edge to another locked input; this can change package derivations compared with the upstream flake’s own lock graph. Noctalia and Vicinae explicitly warn about cache misses when nixpkgs is overridden/followed; CachyOS documents the need for its pinned nixpkgs. See the [Nix flake input/lock documentation](https://github.com/NixOS/nix/blob/master/src/nix/flake.md#inputs).
3. Flake `nixConfig` cache settings are not a substitute for durable host configuration: Nix asks before applying most flake settings unless `accept-flake-config` is enabled globally. The Linux host’s explicit `nix.settings.extra-substituters` and `extra-trusted-public-keys` are its durable settings; macOS currently has none. Nix also verifies cache signatures against trusted public keys when requiring signatures. See [flake `nixConfig`](https://github.com/NixOS/nix/blob/master/src/nix/flake.md#flake-nix) and the [Nix configuration manual](https://nix.dev/manual/nix/2.30/command-ref/conf-file.html#conf-trusted-public-keys).
4. `overrideAttrs` changes the resulting derivation path. The DMS override therefore prevents substituting the unmodified `dms-shell` output, although its dependencies can still come from any matching configured cache.
5. Apart from the targeted CachyOS probe recorded above, this audit reports upstream cache intent and local package selection. Other cache endpoints and exact output paths have not been checked for availability.

## Other direct inputs

The remaining direct inputs are source/framework dependencies rather than an app-specific prebuilt output sought by this audit: `nixpkgs`, `nixpkgs-darwin`, `flake-parts`, `flake-utils`, `import-tree`, `nix-darwin`, `home-manager`, `home-manager-darwin`, and `nix-index-database`. Standard Nixpkgs-built dependencies use `cache.nixos.org` when the exact path is present. The `context7-skills`, `mattpocock-skills`, `humanlayer-skills`, `kitlangton-skills`, `screen-capture-toolbar`, `quick-capture`, and `dms-plugins` inputs are marked `flake = false` or consumed as source/content; they do not expose package outputs with their own flake substituters in this configuration ([input declarations](../flake.nix)).
