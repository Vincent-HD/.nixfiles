{ inputs, config, ... }:
{
  config.flake.username = "vincent"; # Define the username shared across all modules

  config.flake.modules.nixos.pcFixeConfiguration =
    { ... }:
    {
      imports = [
        inputs.self.nixosModules.pcFixeHardware
      ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.systemd-boot.configurationLimit = 10;

      networking.hostName = "pc-fixe";
      networking.enableIPv6 = false;
      networking.networkmanager.enable = true;

      time.timeZone = "Europe/Paris";

      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "fr_FR.UTF-8";
        LC_IDENTIFICATION = "fr_FR.UTF-8";
        LC_MEASUREMENT = "fr_FR.UTF-8";
        LC_MONETARY = "fr_FR.UTF-8";
        LC_NAME = "fr_FR.UTF-8";
        LC_NUMERIC = "fr_FR.UTF-8";
        LC_PAPER = "fr_FR.UTF-8";
        LC_TELEPHONE = "fr_FR.UTF-8";
        LC_TIME = "fr_FR.UTF-8";
      };

      services.xserver.xkb = {
        layout = "fr";
        variant = "azerty";
      };

      console.keyMap = "fr";

      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      users.users.${config.flake.username} = {
        isNormalUser = true;
        description = "Vincent";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
      };

      nixpkgs.config.allowUnfree = true;

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://cachix.cachix.org"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
        ];
      };

      # Mounting Windows + WSL (see modules/features/windows-mounts.nix).
      # NTFS uses kernel ntfs3 (not FUSE) so nixos-rebuild can reload mounts cleanly.
      # If mnt-windows.mount / mnt-data.mount still fail on switch: sudo umount /mnt/windows /mnt/data; sudo nixos-rebuild switch
      # UUIDs: nvme0n1p3 = Windows, sda1 = second disk — verify: sudo blkid | grep -i ntfs
      custom.windowsMounts = {
        enable = true;
        windowsPartitionUuid = "720853E50853A73F";
        sharedDataDrivePartitionUuid = "E29095BC9095981D";
        wslVhdxPath = "/mnt/windows/WSL2-Distros/welii/ext4.vhdx";
      };

      system.stateVersion = "25.11";
    };
}
