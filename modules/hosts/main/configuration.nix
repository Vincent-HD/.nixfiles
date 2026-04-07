{ inputs, config, ... }:
let
  username = config.flake.username;
in
{
  flake.modules.nixos.mainConfiguration =
    { ... }:
    {
      imports = [
        inputs.self.nixosModules.mainHardware
      ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      networking.hostName = "main";
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

      users.users.${username} = {
        isNormalUser = true;
        description = "Vincent";
        extraGroups = [ "networkmanager" "wheel" ];
      };

      nixpkgs.config.allowUnfree = true;

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Mounting Windows + WSL (see modules/features/windows-mounts.nix).
      # NTFS uses kernel ntfs3 (not FUSE) so nixos-rebuild can reload mounts cleanly.
      # If mnt-windows.mount / mnt-data.mount still fail on switch: sudo umount /mnt/windows /mnt/data; sudo nixos-rebuild switch
      # UUIDs: nvme0n1p3 = Windows, sda1 = second disk — verify: sudo blkid | grep -i ntfs
      nixfiles.windowsMounts = {
        enable = true;
        windowsPartitionUuid = "720853E50853A73F";
        sharedDataDrivePartitionUuid = "E29095BC9095981D";
        wslVhdxPath = "/mnt/windows/WSL2-Distros/welii/ext4.vhdx";
      };

      system.stateVersion = "25.11";
    };
}
