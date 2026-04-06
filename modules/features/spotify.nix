{ ... }:
{
  # Home Manager side: Spotify
  flake.modules.homeManager.spotify =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        spotify
      ];
    };
}
