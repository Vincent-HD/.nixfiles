{ ... }:
{
  # Dual-boot: NTFS Windows volume(s) + optional WSL ext4.vhdx via qemu-nbd.
  #
  # Reference: references/neoelectron-nixfiles (hardware + wsl-mount.nix).
  #
  # 1) NTFS: optional fstab mounts at boot — uses `nofail` so a missing/wrong disk does not block boot.
  #    We use the kernel ntfs3 driver (not ntfs-3g FUSE) so systemd can remount/reload on nixos-rebuild
  #    without failing. If a switch still errors on mnt-*.mount, run:
  #      sudo umount /mnt/windows /mnt/data 2>/dev/null; sudo nixos-rebuild switch
  # 2) WSL: never mounted automatically. Only `wsl-mount` / `wsl-umount` (manual). No fstab, no systemd
  #    unit, no kernel module loaded at boot — nbd is modprobed inside the script when you run it.
  #    NEVER mount the VHDX while Windows/WSL is using it — risk of corruption.
  #
  # Enable and fill values in modules/hosts/main/configuration.nix (custom.windowsMounts).
  config.flake.modules.nixos.windowsMounts =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.custom.windowsMounts;
      ntfsOpts = [
        "rw"
        "uid=1000"
        "gid=100"
        "dmask=022"
        "fmask=133"
        "nofail"
      ];
    in
    {
      options.custom.windowsMounts = {
        enable = lib.mkEnableOption ''
          Mount Windows NTFS partition(s) for dual-boot. Set UUIDs from `sudo blkid`.
        '';

        windowsPartitionUuid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "UUID of the Windows NTFS volume (shown as System or C:).";
        };

        sharedDataDrivePartitionUuid = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "UUID of the shared data drive NTFS volume (e.g. D:).";
        };

        wslVhdxPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Absolute path to a WSL2 ext4.vhdx on the Windows volume, e.g.
            /mnt/windows/Users/vincent/AppData/Local/Packages/<DistroPackage>/LocalState/ext4.vhdx.
            Installs wsl-mount / wsl-umount only (run by hand). Does not mount at boot.
          '';
        };
      };

      config = lib.mkMerge [
        (lib.mkIf (cfg.enable && cfg.windowsPartitionUuid != null) {
          fileSystems."/mnt/windows" = {
            device = "/dev/disk/by-uuid/${cfg.windowsPartitionUuid}";
            fsType = "ntfs3"; # use kernel ntfs3 (not ntfs-3g FUSE) so systemd can remount/reload on nixos-rebuild without failing
            options = ntfsOpts;
          };
        })

        (lib.mkIf (cfg.enable && cfg.sharedDataDrivePartitionUuid != null) {
          fileSystems."/mnt/data" = {
            device = "/dev/disk/by-uuid/${cfg.sharedDataDrivePartitionUuid}";
            fsType = "ntfs3"; # use kernel ntfs3 (not ntfs-3g FUSE) so systemd can remount/reload on nixos-rebuild without failing
            options = ntfsOpts;
          };
        })

        (lib.mkIf (cfg.enable && cfg.wslVhdxPath != null) {
          environment.systemPackages = [
            pkgs.qemu-utils

            (pkgs.writeShellScriptBin "wsl-mount" ''
              set -euo pipefail

              VHDX="${cfg.wslVhdxPath}"
              MOUNT="/mnt/wsl"
              DEV="/dev/nbd0"

              if mountpoint -q "$MOUNT"; then
                echo "Already mounted at $MOUNT"
                exit 0
              fi

              if [ ! -f "$VHDX" ]; then
                echo "Error: VHDX not found at $VHDX"
                echo "Is the Windows partition mounted at /mnt/windows (and path correct)?"
                exit 1
              fi

              sudo mkdir -p "$MOUNT"

              sudo ${pkgs.kmod}/bin/modprobe nbd max_part=8
              sudo ${pkgs.qemu-utils}/bin/qemu-nbd --connect="$DEV" "$VHDX"
              sleep 1

              if [ -b "''${DEV}p1" ]; then
                sudo mount "''${DEV}p1" "$MOUNT"
              else
                sudo mount "$DEV" "$MOUNT"
              fi

              echo "Mounted WSL disk at $MOUNT"
            '')

            (pkgs.writeShellScriptBin "wsl-umount" ''
              set -euo pipefail

              MOUNT="/mnt/wsl"
              DEV="/dev/nbd0"

              if mountpoint -q "$MOUNT"; then
                sudo umount "$MOUNT"
                echo "Unmounted $MOUNT"
              else
                echo "$MOUNT is not mounted"
              fi

              if [ -b "$DEV" ]; then
                sudo ${pkgs.qemu-utils}/bin/qemu-nbd --disconnect "$DEV" 2>/dev/null || true
                echo "Disconnected $DEV"
              fi
            '')
          ];
        })
      ];
    };
}
