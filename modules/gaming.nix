{ ... }:
{
  config.flake.modules.nixos.gaming =
    { pkgs, config, ... }:
    let
      cpuidFaultEmulation = pkgs.callPackage ../packages/cpuid-fault-emulation {
        kernel = config.boot.kernelPackages.kernel;
      };
      cpuidHypervisorStart = pkgs.writeShellApplication {
        name = "cpuid-hypervisor-start";
        runtimeInputs = [ pkgs.kmod ];
        text = ''
          if [ "$(id -u)" -ne 0 ]; then
            echo "Run this command with sudo."
            exit 1
          fi

          if ! modprobe -r kvm_amd kvm; then
            echo "KVM is busy. Shut down virtual machines and unload other AMD-V users first."
            exit 1
          fi

          if ! modprobe cpuid_fault_emulation; then
            echo "Could not load cpuid_fault_emulation; restoring KVM."
            modprobe kvm_amd kvm
            exit 1
          fi
        '';
      };
      cpuidHypervisorStop = pkgs.writeShellApplication {
        name = "cpuid-hypervisor-stop";
        runtimeInputs = [ pkgs.kmod ];
        text = ''
          if [ "$(id -u)" -ne 0 ]; then
            echo "Run this command with sudo."
            exit 1
          fi

          modprobe -r cpuid_fault_emulation
          modprobe kvm_amd kvm
        '';
      };
      steamInstallCustomProton = pkgs.writeShellApplication {
        name = "steam-install-custom-proton";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gawk
          pkgs.gnutar
        ];
        text = ''
          if [ "$#" -ne 1 ]; then
            echo "Usage: steam-install-custom-proton <proton-archive>"
            exit 1
          fi

          proton_archive="$1"
          steam_tools_dir="$HOME/.local/share/Steam/compatibilitytools.d"

          if [ ! -f "$proton_archive" ]; then
            echo "Archive not found: $proton_archive"
            exit 1
          fi

          # Reject archive entries that could write outside the temporary extraction directory.
          if tar -tf "$proton_archive" | awk 'BEGIN { valid = 1 } /^\// || /(^|\/)\.\.\// { valid = 0 } END { exit !valid }'; then
            :
          else
            echo "Archive contains an unsafe path."
            exit 1
          fi

          mkdir -p "$steam_tools_dir"
          staging_dir="$(mktemp -d "$steam_tools_dir/.custom-proton.XXXXXX")"
          trap 'rm -rf "$staging_dir"' EXIT

          tar -xf "$proton_archive" -C "$staging_dir"

          mapfile -t proton_directories < <(find "$staging_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
          if [ "''${#proton_directories[@]}" -ne 1 ]; then
            echo "Archive must contain exactly one top-level Proton directory."
            exit 1
          fi

          proton_name="''${proton_directories[0]}"
          proton_directory="$staging_dir/$proton_name"
          destination="$steam_tools_dir/$proton_name"

          if [ ! -f "$proton_directory/compatibilitytool.vdf" ]; then
            echo "Archive does not contain a Steam compatibility tool."
            exit 1
          fi

          if [ -e "$destination" ]; then
            echo "Compatibility tool already exists: $destination"
            exit 1
          fi

          mv "$proton_directory" "$destination"
          echo "Installed $proton_name. Fully restart Steam, then choose it in the game's Compatibility settings."
        '';
      };
    in
    {
      # Keep the module available for manual game-session activation without loading it at boot.
      boot.extraModulePackages = [ cpuidFaultEmulation ];

      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        protontricks.enable = true;
        # MangoHud adds the in-game performance overlay for Steam titles.
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        # Steam launch options need Gamescope available inside Steam's runtime environment.
        extraPackages = [
          pkgs.gamescope
          pkgs.mangohud
        ];
        # GameScope runs Steam inside a dedicated compositor session.
        gamescopeSession.enable = true;
      };

      # GameScope is the compositor used for Steam Deck-style fullscreen gaming sessions.
      programs.gamescope = {
        enable = true;
      };

      programs.gamemode.enable = true;

      # Make the MangoHud CLI available outside Steam as well.
      environment.systemPackages = [
        # Heroic provides a launcher for Epic Games, GOG, and Amazon Games libraries.
        pkgs.heroic
        # Lutris provides a separate Wine/Proton launcher path for compatibility testing.
        pkgs.lutris
        pkgs.mangohud
        cpuidHypervisorStart
        cpuidHypervisorStop
        steamInstallCustomProton
      ];
    };
}
