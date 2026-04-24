{ ... }:
{
  # Home Manager: Bottles desktop client for managing Windows prefixes
  config.flake.modules.homeManager.bottles =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.bottles
      ];
    };
}
