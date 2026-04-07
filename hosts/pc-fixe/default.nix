{ inputs, config, ... }:
let
  nixos = config.flake.modules.nixos;
  hm = config.flake.modules.homeManager;
  username = config.flake.username;
in
{
  config.flake.nixosConfigurations."pc-fixe" = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      # ── System-level modules ──────────────────────────────
      nixos.pcFixeConfiguration
      nixos.plasma
      nixos.graphics
      nixos.sound
      nixos.coding
      nixos.printing
      nixos.gparted
      nixos.windowsMounts

      # ── Home Manager integration ─────────────────────────
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # When HM tries to overwrite a file it did not create (created by 3rd party software)
        # we indicate to HM to rename the old file to ".hm-backup" first, then install the managed one.
        home-manager.backupFileExtension = "hm-backup";
        home-manager.sharedModules = [ inputs.nixcord.homeModules.nixcord ];
        home-manager.users.${username} = {
          imports = [
            hm.plasma
            hm.coding
            hm.browser
            hm.discord
            hm.spotify
            hm.bitwarden
            hm.curseforge
            hm.work
          ];

          home.username = username;
          home.homeDirectory = "/home/${username}";
          home.stateVersion = "25.11";
        };
      }
    ];
  };
}
