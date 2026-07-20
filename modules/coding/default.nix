{ config, ... }:
let
  homeManagerModules = config.flake.modules.homeManager;
  username = config.flake.username;
in
{
  config.flake.modules.nixos.coding =
    { ... }:
    {
      programs.nix-ld.enable = true;

      virtualisation.docker.enable = true;

      users.users.${username}.extraGroups = [ "docker" ];
    };

  config.flake.modules.homeManager.coding =
    { ... }:
    {
      # Keep host imports stable while import-tree discovers the smaller modules
      # living beside this file.
      imports = [
        homeManagerModules.codingEditors
        homeManagerModules.codingGit
        homeManagerModules.codingJujutsu
        homeManagerModules.codingNixTools
      ];
    };
}
