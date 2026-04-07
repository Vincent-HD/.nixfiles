{ ... }:
{
  # Home Manager side: Work tools
  config.flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.slack
      ];
    };
}
