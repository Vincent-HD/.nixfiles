{ config, ... }:
let
  username = config.flake.username;
in
{
  config.flake.modules.nixos.moonshine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.moonshine;
      settingsFormat = pkgs.formats.toml { };
      configFile = settingsFormat.generate "moonshine-config.toml" cfg.settings;
      runtimeDir = "/run/user/${toString cfg.uid}";
      package = pkgs.callPackage ../packages/moonshine { };
      moonshineTcpPorts = [
        (cfg.settings.webserver.port_https or 47984)
        (cfg.settings.webserver.port or 47989)
        (cfg.settings.stream.port or 48010)
      ];
      moonshineUdpPorts = [
        5353
        (cfg.settings.stream.video.port or 47998)
        (cfg.settings.stream.control.port or 47999)
        (cfg.settings.stream.audio.port or 48000)
      ];
    in
    {
      options.services.moonshine = {
        enable = lib.mkEnableOption "Moonshine, a game streaming server for Moonlight clients";

        user = lib.mkOption {
          type = lib.types.str;
          default = username;
          description = "User whose applications Moonshine launches for streaming.";
        };

        # Vincent's local uid is fixed by the existing NixOS installation and is
        # needed before the user manager has started during boot.
        uid = lib.mkOption {
          type = lib.types.int;
          default = 1000;
          description = "Numeric uid of the Moonshine user.";
        };

        settings = lib.mkOption {
          inherit (settingsFormat) type;
          default = { };
          description = "Moonshine configuration, written as Nix and rendered to TOML.";
        };

        logFilter = lib.mkOption {
          type = lib.types.str;
          default = "moonshine=info";
          description = "Value for Moonshine's MOONSHINE_LOG environment variable.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open Moonshine's ports to the trusted LAN IPv4 subnet.";
        };

        trustedNetwork = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.0/24";
          description = "IPv4 CIDR allowed to reach Moonshine when openFirewall is enabled.";
        };
      };

      config = lib.mkMerge [
        {
          services.moonshine.enable = true;
          # Expose the GameStream ports on the trusted LAN/VPN firewall interface.
          services.moonshine.openFirewall = true;
        }
        (lib.mkIf cfg.enable {
          # Replace upstream's /usr/bin/steam default with NixOS paths and expose
          # the locally installed Steam and Lutris libraries to Moonlight.
          services.moonshine.settings = lib.mkDefault {
            name = "PC-FIXE NIXOS";
            application = [
              {
                title = "Steam";
                command = [
                  "/run/current-system/sw/bin/steam"
                  "-bigpicture"
                ];
              }
              {
                title = "Niri Desktop (Noctalia)";
                # Moonshine already provides the outer headless compositor. Start Niri
                # without --session so it nests inside that compositor, and include the
                # Home Manager profile so Niri can start the user's Noctalia shell.
                command = [
                  "/run/current-system/sw/bin/env"
                  "PATH=/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
                  "/run/current-system/sw/bin/niri"
                ];
              }
            ];
            application_scanner = [
              {
                type = "steam";
                library = "$HOME/.local/share/Steam";
                command = [
                  "/run/current-system/sw/bin/steam"
                  "-bigpicture"
                  "steam://rungameid/{game_id}"
                ];
              }
              {
                type = "lutris";
                command = [
                  "/run/current-system/sw/bin/lutris"
                  "lutris:rungame/{slug}"
                ];
              }
            ];
          };

          environment.systemPackages = [ package ];

          # Grant Moonshine access to virtual input devices and install its suspend rule.
          services.udev.packages = [ package ];
          users.groups.moonshine = { };

          # Moonshine creates virtual keyboard, mouse, and gamepad devices.
          boot.kernelModules = [
            "uinput"
            "uhid"
          ];

          # Keep the user manager and D-Bus session available for headless launches.
          users.users.${cfg.user}.linger = true;

          systemd.services.moonshine = {
            description = "Moonshine game streaming server (Moonlight protocol)";
            wantedBy = [ "multi-user.target" ];
            requires = [ "user@${toString cfg.uid}.service" ];
            after = [ "user@${toString cfg.uid}.service" ];
            path = [ pkgs.xwayland ];
            environment = {
              MOONSHINE_LOG = cfg.logFilter;
              XDG_RUNTIME_DIR = runtimeDir;
              DBUS_SESSION_BUS_ADDRESS = "unix:path=${runtimeDir}/bus";
              # Make the release-bundled implicit layer visible even when the
              # Vulkan loader is not searching the Nix profile automatically.
              VK_LAYER_PATH = "${package}/share/vulkan/implicit_layer.d";
            };
            serviceConfig = {
              User = cfg.user;
              SupplementaryGroups = [
                "input"
                "moonshine"
                "render"
                "video"
              ];
              ExecStart = "${lib.getExe package} ${configFile}";
              Restart = "on-failure";
              RestartSec = 5;
            };
          };

          # Use NixOS's declarative nftables rules so only the trusted IPv4
          # network can reach Moonshine. Interface-scoped allowed ports would
          # also allow the host's globally routable IPv6 address.
          networking.nftables.enable = true;
          networking.firewall.extraInputRules = lib.mkIf cfg.openFirewall ''
            ip saddr ${cfg.trustedNetwork} tcp dport { ${lib.concatStringsSep ", " (map toString moonshineTcpPorts)} } accept
            ip saddr ${cfg.trustedNetwork} udp dport { ${lib.concatStringsSep ", " (map toString moonshineUdpPorts)} } accept
          '';
        })
      ];
    };
}
