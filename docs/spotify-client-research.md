# Spotify client research for NixOS

Research date: 2026-08-19

## Recommendation

The closest Spotify equivalent to `nixcord` is [Spicetify-Nix](https://github.com/Gerg-L/spicetify-nix): it provides NixOS and Home Manager modules for the official Spotify client. Pair it with Spicetify's [Lyrics Plus](https://spicetify.app/docs/customization/custom-apps) custom app.

Lyrics Plus is the strongest match for the requested lyrics behavior. Its current provider implementation includes Spotify's internal lyrics, Musixmatch, Netease, LRCLIB, Genius, and a local cache; it supports karaoke, synced, and unsynced modes. Providers can be enabled and reordered, and the app tries them in order when a provider cannot satisfy the requested mode. The [provider source](https://github.com/spicetify/cli/blob/main/CustomApps/lyrics-plus/Providers.js), [fallback logic](https://github.com/spicetify/cli/blob/main/CustomApps/lyrics-plus/index.js), and [Spicetify-Nix custom-app documentation](https://gerg-l.github.io/spicetify-nix/custom-apps.html) confirm this directly.

For the stated priority of explicit or missing music, I would start with this provider order:

`Musixmatch → LRCLIB → Netease → Spotify → local`

If exact Spotify metadata and official availability matter more than coverage, put Spotify first. This order is a coverage preference, not a guarantee: lyric providers have different catalogs, content policies, and rate limits. LRCLIB is particularly useful as a free, keyless fallback with exact and fuzzy search ([API documentation](https://lrclib.net/docs)); Musixmatch can occasionally rate-limit or flag its token ([Spicetify FAQ](https://spicetify.app/docs/faq)).

## Candidates

| Candidate | Lyrics and playback | Assessment |
| --- | --- | --- |
| **Official Spotify + Spicetify-Nix + Lyrics Plus** | Full official Spotify playback/library; synced and karaoke lyrics with multiple external providers | **Best overall fit.** Heavier than a TUI and dependent on Spicetify keeping up with Spotify updates. Spotify itself describes the Linux client as community-supported rather than actively supported ([official Linux download page](https://www.spotify.com/bf-en/download/linux/)). |
| **[spotatui](https://github.com/LargeModGames/spotatui)** | Native Spotify streaming in a Rust/Ratatui TUI; synced lyrics from LRCLIB with exact matching, fuzzy search, and a plain-lyrics fallback ([lyrics source](https://github.com/LargeModGames/spotatui/blob/main/src/infra/network/utils.rs)) | **Best lightweight all-in-one option.** The project reports roughly 78 MB RAM while streaming/syncing lyrics, but it has one lyrics backend and is not a full desktop GUI. Spotify Premium is required. |
| **[Spotube](https://github.com/KRTirtho/spotube)** | Lightweight GUI; synced lyrics currently come from LRCLIB ([implementation](https://github.com/KRTirtho/spotube/blob/master/lib/provider/lyrics/synced.dart)) | Attractive UI, but it is not complete Spotify playback: the project uses Spotify metadata and obtains audio from sources such as YouTube/Piped rather than Spotify's audio stream ([project discussion](https://github.com/KRTirtho/spotube/discussions/951)). LRCLIB-only coverage has also been reported as a limitation ([issue #1491](https://github.com/KRTirtho/spotube/issues/1491)). |
| **[spotify-player](https://github.com/aome510/spotify-player) + [sptlrx](https://github.com/raitonoberu/sptlrx)** | Native Spotify streaming and synced Spotify lyrics; sptlrx adds a separate LRCLIB-based lyrics viewer | Good terminal stack, but third-party lyrics are not integrated into spotify-player. Its current lyrics code calls Spotify's internal metadata only ([source](https://github.com/aome510/spotify-player/blob/master/spotify_player/src/client/mod.rs)). |
| **[ncspot](https://github.com/hrkfdn/ncspot)** | Very light native Spotify TUI | No integrated lyrics provider in the current project, so it fails the central requirement. |
| Riff, Psst, spotify-qt, Spotifust | Lightweight GUI experiments with varying Spotify/librespot support | Scouted, but none currently combines complete playback with synced lyrics and a credible third-party fallback. |

## NixOS implementation impact

The existing [`modules/spotify.nix`](/home/vincent/.nixfiles/modules/spotify.nix) only installs `pkgs.spotify`. If implementing the recommendation, the module would instead add the `spicetify-nix` flake input, import its Home Manager module, enable `programs.spicetify`, and add `spicePkgs.apps.lyricsPlus`. The upstream module installs the wrapped Spotify package, so `pkgs.spotify` should not also be added separately ([usage documentation](https://gerg-l.github.io/spicetify-nix/usage.html), [NixOS Wiki](https://wiki.nixos.org/wiki/Spicetify-Nix)).

No Nix configuration was changed as part of this research. If implemented, the new flake input will also need to follow this repository's pinned-input/update-registry conventions.

## Bottom line

1. Choose **Spicetify-Nix + Lyrics Plus** for a complete Spotify desktop client and the best multi-provider lyrics coverage.
2. Choose **spotatui** if “light” outweighs GUI completeness and LRCLIB alone is acceptable.
3. Avoid Spotube for this use case if “Spotify” means Spotify's actual audio service rather than Spotify metadata and alternative audio sources.
