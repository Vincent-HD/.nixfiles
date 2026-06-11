{ ... }:
{
  config.flake.modules.homeManager.mcfly =
    { pkgs, ... }:
    {
      # Keep shell integration and McFly settings in the existing user-managed
      # shell files until shell configuration is migrated as its own boundary.
      home.packages = [ pkgs.mcfly ];
    };
}
