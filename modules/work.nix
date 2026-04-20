{ ... }:
{
  # Home Manager side: Work tools
  config.flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.doppler
        pkgs.awscli
        pkgs.jetbrains.datagrip
      ];
    };
}
