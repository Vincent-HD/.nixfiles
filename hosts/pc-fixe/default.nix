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
      nixos.secrets
      inputs.sops-nix.nixosModules.sops
      nixos.pcFixeConfiguration
      nixos.niri
      nixos.noctalia
      nixos.graphics
      nixos.sound
      nixos.coding
      nixos.printing
      nixos.gparted
      nixos.windowsMounts
      nixos.sunshine
      nixos.gaming

      # ── Home Manager integration ─────────────────────────
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # When HM tries to overwrite a file it did not create (created by 3rd party software)
        # we indicate to HM to rename the old file to ".hm-backup" first, then install the managed one.
        home-manager.backupFileExtension = "hm-backup";
        home-manager.users.${username} = {
          imports = [
            #hm.plasma
            hm.cursorPointer
            hm.niri
            hm.noctalia
            hm.noctalia-plugins-dependencies
            hm.coding
            hm.discord
            hm.browser
            hm.spotify
            hm.vicinae
            hm.bitwarden
            hm.curseforge
            hm.onlyoffice
            hm.work
            hm.kdeConnect
            hm.xerahs
          ];

          custom.niri.audioBinds = {
            volumeUpKey = "XF86AudioRaiseVolume";
            volumeDownKey = "XF86AudioLowerVolume";
            muteKey = "XF86AudioMute";
          };

          custom.niri.mediaBinds = {
            playPauseKey = "XF86AudioPlay";
            stopKey = "XF86AudioStop";
            previousKey = "XF86AudioPrev";
            nextKey = "XF86AudioNext";
          };

          home.username = username;
          home.homeDirectory = "/home/${username}";
          home.stateVersion = "25.11";
        };
      }
    ];
  };
}
