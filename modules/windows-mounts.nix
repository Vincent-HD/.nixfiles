{ ... }:
{
  # Dual-boot: NTFS Windows volume(s) + optional WSL ext4.vhdx via qemu-nbd.
  #
  # Reference: ~/.references/neolectron_nixfiles (hardware + wsl-mount.nix).
  #
  # 1) NTFS: optional fstab mounts at boot — uses systemd automount so a missing/wrong/hibernated
  #    Windows disk does not block boot or nixos-rebuild switch. Accessing the mountpoint triggers
  #    the actual mount attempt.
  # 2) WSL: never mounted automatically. Only `wsl-mount` / `wsl-umount` (manual). No fstab, no systemd
  #    unit, no kernel module loaded at boot — nbd is modprobed inside the script when you run it.
  #    NEVER mount the VHDX while Windows/WSL is using it — risk of corruption.
  #    Usage: wsl-mount [distro] [mountpoint] — e.g. `wsl-mount znope /mnt/znope`. Mounts read-write;
  #    set WSL_MOUNT_RO=1 for a read-only mount when you only need to inspect or extract from it.
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
        "noauto"
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
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

              DISTRO_ROOT="$(dirname "$(dirname "${cfg.wslVhdxPath}")")"
              DISTRO="''${1:-$(basename "$(dirname "${cfg.wslVhdxPath}")")}"
              MOUNT="''${2:-/mnt/wsl}"
              VHDX="$DISTRO_ROOT/$DISTRO/ext4.vhdx"
              DEV="/dev/nbd0"

              if mountpoint -q "$MOUNT"; then
                echo "Already mounted at $MOUNT"
                exit 0
              fi

              if [ ! -f "$VHDX" ]; then
                echo "Error: VHDX not found at $VHDX"
                echo "Available distros in $DISTRO_ROOT:"
                ls -1 "$DISTRO_ROOT" 2>/dev/null || true
                echo "Is the Windows partition mounted at /mnt/windows (and path correct)?"
                exit 1
              fi

              MOUNT_OPTS="rw"
              if [ "''${WSL_MOUNT_RO:-0}" = "1" ]; then
                MOUNT_OPTS="ro"
              fi

              sudo mkdir -p "$MOUNT"

              sudo ${pkgs.kmod}/bin/modprobe nbd max_part=8
              sudo ${pkgs.qemu-utils}/bin/qemu-nbd --connect="$DEV" "$VHDX"
              sleep 1

              if [ -b "''${DEV}p1" ]; then
                sudo mount -o "$MOUNT_OPTS" "''${DEV}p1" "$MOUNT"
              else
                sudo mount -o "$MOUNT_OPTS" "$DEV" "$MOUNT"
              fi

              echo "Mounted WSL disk ($DISTRO, $MOUNT_OPTS) at $MOUNT"
            '')

            (pkgs.writeShellScriptBin "wsl-umount" ''
              set -euo pipefail

              MOUNT="''${1:-/mnt/wsl}"
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
