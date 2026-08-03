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
          description = "Open Moonshine's GameStream ports in the firewall.";
        };
      };

      config = lib.mkMerge [
        { services.moonshine.enable = true; }
        (lib.mkIf cfg.enable {
          # Replace upstream's /usr/bin/steam default with NixOS paths and expose
          # the locally installed Steam and Lutris libraries to Moonlight.
          services.moonshine.settings = lib.mkDefault {
            application = [
              {
                title = "Steam";
                command = [ "/run/current-system/sw/bin/steam" "-bigpicture" ];
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
                command = [ "/run/current-system/sw/bin/lutris" "lutris:rungame/{slug}" ];
              }
            ];
          };

          environment.systemPackages = [ package ];

          # Grant Moonshine access to virtual input devices and install its suspend rule.
          services.udev.packages = [ package ];
          users.groups.moonshine = { };

          # Moonshine creates virtual keyboard, mouse, and gamepad devices.
          boot.kernelModules = [ "uinput" "uhid" ];

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
              SupplementaryGroups = [ "input" "render" "video" ];
              ExecStart = "${lib.getExe package} ${configFile}";
              Restart = "on-failure";
              RestartSec = 5;
            };
          };

          networking.firewall = lib.mkIf cfg.openFirewall {
            allowedTCPPorts = [
              (cfg.settings.webserver.port_https or 47984)
              (cfg.settings.webserver.port or 47989)
              (cfg.settings.stream.port or 48010)
            ];
            allowedUDPPorts = [
              (cfg.settings.stream.video.port or 47998)
              (cfg.settings.stream.control.port or 47999)
              (cfg.settings.stream.audio.port or 48000)
            ];
          };
        })
      ];
    };
}
