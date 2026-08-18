{ inputs, ... }:
{
  # Home Manager side: official Spotify wrapped by Spicetify with lyrics and useful library tools.
  config.flake.modules.homeManager.spotify =
    { pkgs, ... }:
    let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

      programs.spicetify = {
        enable = true;

        # Use XWayland to avoid Spotify's broken native-Wayland title bar.
        wayland = false;

        # Lyrics Plus provides synced lyrics with third-party provider fallbacks.
        enabledCustomApps = [
          spicePkgs.apps.lyricsPlus
        ];

        # History, playlist sorting, and current-session listening metrics.
        enabledExtensions = [
          spicePkgs.extensions.history
          spicePkgs.extensions.sortPlay
          spicePkgs.extensions.sessionStats
          spicePkgs.extensions.shuffle
          spicePkgs.extensions.powerBar
        ];
      };
    };
}
