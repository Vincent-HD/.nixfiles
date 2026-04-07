{ ... }:
{
  # Home Manager side: Spotify
  config.flake.modules.homeManager.spotify =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.spotify
      ];
    };
}
