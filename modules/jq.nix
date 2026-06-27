{ ... }:
{
  config.flake.modules.homeManager.jq =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.jq ];
    };
}
