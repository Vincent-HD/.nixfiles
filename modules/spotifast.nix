{
  # Home Manager side: Spotifast, the lightweight native Spotify client from nixpkgs.
  # Playback needs Spotify Premium. The built-in player tops out at 320 kbps.
  config.flake.modules.homeManager.spotifast =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.spotifast ];
    };
}
