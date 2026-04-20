{ ... }:
{
  # Home Manager side: Vicinae launcher
  config.flake.modules.homeManager.vicinae =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.vicinae
      ];
    };
}
