{ inputs, config, ... }:
{
  config.flake.modules.nixos.pcFixeConfiguration =
    { pkgs, ... }:
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

      programs.zsh.enable = true;

      users.users.${config.flake.username} = {
        isNormalUser = true;
        description = "Vincent";
        # Use the same interactive shell family as macOS.
        shell = pkgs.zsh;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
      };

      nixpkgs.config.allowUnfree = true;
      # Bitwarden Desktop currently pins an EOL Electron. Allow it until nixpkgs
      # ships a version built against a supported Electron release.
      nixpkgs.config.permittedInsecurePackages = [
        "electron-39.8.10"
      ];

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # Binary caches for flake-backed packages that are not reliably covered by cache.nixos.org.
        extra-substituters = [
          "https://codex-desktop-linux.cachix.org"
          "https://codex-cli.cachix.org"
          "https://ghostty.cachix.org"
          "https://hyprland.cachix.org"
          "https://nix-gaming.cachix.org"
          "https://noctalia.cachix.org"
          "https://vicinae.cachix.org"
          "https://nix-community.cachix.org"
          "https://cachix.cachix.org"
          "https://niri.cachix.org"
        ];
        extra-trusted-public-keys = [
          "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
          "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
          "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
          "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        ];
      };

      # Mounting Windows + WSL (see modules/features/windows-mounts.nix).
      # NTFS mounts are systemd automounts, so nixos-rebuild does not fail when Windows leaves
      # the partition hibernated/dirty. Accessing /mnt/windows or /mnt/data triggers the mount.
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
