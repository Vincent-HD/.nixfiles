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
      nixos.niri
      nixos.dms
      nixos.graphics
      nixos.sound
      nixos.wifiAudioStreaming
      nixos.memoryPressure
      nixos.coding
      nixos.agentCodex
      nixos.portless
      nixos.printing
      nixos.gparted
      nixos.windowsMounts
      nixos.fonts
      nixos.sunshine
      nixos.gaming
      nixos.lsfgVk
      nixos.gamingOptimization
      nixos.deskflow
      nixos.localSend
      nixos.androidPhone
      nixos.tailscale

      # ── Home Manager integration ─────────────────────────
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # When HM tries to overwrite a file it did not create (created by 3rd party software)
        # we indicate to HM to rename the old file to ".hm-backup" first, then install the managed one.
        home-manager.backupFileExtension = "hm-backup";
        home-manager.users.${username} = {
          # Use the reviewed Z Code fork; `nrs --no-z-code` selects the upstream fallback.
          custom.t3code.enableZCode = true;
          # Keep the upstream patch build ready as a one-switch fallback.
          custom.t3code.enableUsagePatch = true;
          custom.t3code.enableJjPanel = true;
          # Offer temporary conversations with a confirmation before leaving.
          custom.t3code.enableTemporaryThreads = true;
          imports = [
            #hm.plasma
            hm.cursorPointer
            hm.niri
            hm.graphics
            hm.dms
            hm.easyeffects
            hm.dankmail
            hm.tokitoki
            hm.coding
            hm.agentCommon
            hm.agentSkills
            hm.agentClaude
            hm.agentOpencode
            hm.agentCursor
            hm.agentCodex
            hm.agentT3Code
            hm.agentVscode
            hm.executor
            hm.plannotator
            hm.commandLine
            hm.comma
            hm.direnv
            hm.lazydocker
            hm.equibop
            hm.browser
            hm.thunar
            hm.spotify
            hm.vicinae
            hm.bitwarden
            hm.curseforge
            hm.onlyoffice
            hm.work
            hm.kdeConnect
            hm.deskflow
            hm.localSend
            hm.handy
            hm.androidPhone
            hm.wifiAudioStreaming
            hm.ghostty
          ];

          home.packages = [ inputs.self.packages.x86_64-linux.crosspipe ];

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
