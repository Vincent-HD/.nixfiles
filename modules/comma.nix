{ ... }:
{
  # Home Manager side: comma command wrapper plus nix-index database.
  config.flake.modules.homeManager.comma =
    { pkgs, ... }:
    {
      programs.nix-index.enable = true;

      home.packages = [ pkgs.comma ];
    };
}
