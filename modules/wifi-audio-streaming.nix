{ inputs, ... }:
{
  # Let the Linux client receive multicast discovery beacons from the phone.
  config.flake.modules.nixos.wifiAudioStreaming =
    { ... }:
    {
      networking.firewall.allowedUDPPorts = [ 9091 ];
    };

  # Install the desktop receiver on Linux and macOS.
  config.flake.modules.homeManager.wifiAudioStreaming =
    { pkgs, lib, ... }:
    let
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wifi-audio-streaming;
      # Java's tray uses GTK/X11; wait for Xwayland and DMS before initializing it.
      autostart = pkgs.writeShellApplication {
        name = "wifi-audio-streaming-autostart";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.glib
          pkgs.gnugrep
          pkgs.xdpyinfo
        ];
        text = ''
          export GDK_BACKEND=x11
          # Keep Dorkbox's desktop probes small and use its SNI-compatible KDE path on Niri.
          export PS_FORMAT=pid,comm
          case "''${XDG_CURRENT_DESKTOP:-}" in
            *niri*) export XDG_CURRENT_DESKTOP=KDE ;;
          esac
          attempt=0
          while [ "$attempt" -lt 30 ]; do
            if xdpyinfo >/dev/null 2>&1 && gdbus call --session \
              --dest org.freedesktop.DBus \
              --object-path /org/freedesktop/DBus \
              --method org.freedesktop.DBus.NameHasOwner \
              org.kde.StatusNotifierWatcher 2>/dev/null | grep -q 'true'; then
              exec ${lib.getExe package}
            fi
            attempt=$((attempt + 1))
            sleep 1
          done

          printf '%s\n' "WiFi Audio Streaming: X11 display or desktop tray was not ready within 30 seconds" >&2
          exit 1
        '';
      };
      # Keep receiver auto-connect and startup preferences in the app's native JSON format.
      clientConfig = (pkgs.formats.json { }).generate "wifi-audio-streaming-config.json" {
        app = {
          autoConnectClientEnabled = true;
          autoConnectIps = [
            "192.168.1.20"
            "192.168.1.21"
          ];
          autoConnectIntervalSec = 5;
          autoConnectRetryDelaySec = 10;
          autoConnectPromptForKey = false;
          launchAtStartup = true;
          startMinimizedToTray = true;
          # Preserve the existing user's preference to disable update checks.
          autoUpdateCheckEnabled = false;
        };
        # Preserve the existing user's preference to hide the audio visualizer.
        ui.visualizer = false;
      };
    in
    {
      home.packages = [ package ];

      xdg.desktopEntries.wifi-audio-streaming = lib.mkIf isLinux {
        name = "WiFi Audio Streaming";
        genericName = "Network audio receiver";
        comment = "Send or receive audio over the local network";
        exec = lib.getExe autostart;
        icon = "audio-x-generic";
        terminal = false;
        categories = [
          "AudioVideo"
          "Network"
        ];
      };

      xdg.configFile = lib.mkIf isLinux {
        "wfas/config.json" = {
          source = clientConfig;
          force = true;
        };

        "autostart/wifiaudiostreaming.desktop" = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=WiFi Audio Streaming
            Comment=Connect to the saved WFAS servers at login
            Exec=${lib.getExe autostart}
            Terminal=false
            X-GNOME-Autostart-enabled=true
          '';
          force = true;
        };

        # Recover from a native tray crash without restarting after an intentional Quit.
        "systemd/user/app-wifiaudiostreaming@autostart.service.d/restart.conf".text = ''
          [Unit]
          StartLimitIntervalSec=120
          StartLimitBurst=3

          [Service]
          Restart=on-failure
          RestartSec=5s
        '';
      };
    };
}
