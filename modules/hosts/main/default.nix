{ inputs, config, ... }:
let
  nixos = config.flake.modules.nixos;
  hm = config.flake.modules.homeManager;
  username = config.flake.username;
in
{
  flake.nixosConfigurations.main = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      # ── System-level modules ──────────────────────────────
      nixos.mainConfiguration
      nixos.plasma
      nixos.graphics
      nixos.sound
      nixos.coding
      nixos.printing
      nixos.gparted

      # ── Home Manager integration ─────────────────────────
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.sharedModules = [ inputs.nixcord.homeModules.nixcord ];
        home-manager.users.${username} = {
          imports = [
            hm.plasma
            hm.coding
            hm.browser
            hm.discord
            hm.spotify
            hm.bitwarden
          ];

          home.username = username;
          home.homeDirectory = "/home/${username}";
          home.stateVersion = "25.11";
        };
      }
    ];
  };
}
