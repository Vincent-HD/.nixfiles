{ inputs, ... }:
{
  # Home Manager side: install comma with the prebuilt nix-index database.
  config.flake.modules.homeManager.comma =
    { ... }:
    {
      imports = [
        inputs.nix-index-database.homeModules.default
      ];

      programs.nix-index-database.comma.enable = true;
    };
}
