{ config, ... }:
let
  username = config.flake.username;
in
{
  # Inactive fallback: Moonshine streaming through the nixpkgs package and NixOS module.
  config.flake.modules.nixos.moonshine =
    { lib, pkgs, ... }:
    let
      trustedNetwork = "192.168.1.0/24";
      settings = {
        name = "PC-FIXE NIXOS";
        application = [
          {
            title = "Steam";
            command = [
              "steam"
              "-bigpicture"
            ];
          }
          {
            title = "Niri Desktop";
            command = [
              "env"
              "PATH=/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
              "niri"
            ];
          }
        ];
        application_scanner = [
          {
            type = "steam";
            library = "$HOME/.local/share/Steam";
            command = [
              "steam"
              "-bigpicture"
              "steam://rungameid/{game_id}"
            ];
          }
          {
            type = "lutris";
            command = [
              "lutris"
              "lutris:rungame/{slug}"
            ];
          }
        ];
      };
      tcpPorts = [
        (settings.webserver.port_https or 47984)
        (settings.webserver.port or 47989)
        (settings.stream.port or 48010)
      ];
      udpPorts = [
        5353
        (settings.stream.video.port or 47998)
        (settings.stream.control.port or 47999)
        (settings.stream.audio.port or 48000)
      ];
    in
    {
      services.moonshine = {
        enable = true;
        user = username;
        settings = settings;
        extraPackages = [
          pkgs.lutris
          pkgs.niri
          pkgs.steam
        ];
        environment = {
          MOONSHINE_LOG = "moonshine=info";
          VK_LAYER_PATH = "${pkgs.moonshine}/share/vulkan/implicit_layer.d";
        };
      };

      # The user manager and D-Bus session must exist before headless application launches.
      systemd.services.moonshine = {
        requires = [ "user@1000.service" ];
        after = [ "user@1000.service" ];
        serviceConfig.SupplementaryGroups = [
          "render"
          "video"
        ];
      };

      # Limit GameStream access to the trusted IPv4 LAN instead of opening global ports.
      networking.nftables.enable = true;
      networking.firewall.extraInputRules = ''
        ip saddr ${trustedNetwork} tcp dport { ${lib.concatStringsSep ", " (map toString tcpPorts)} } accept
        ip saddr ${trustedNetwork} udp dport { ${lib.concatStringsSep ", " (map toString udpPorts)} } accept
      '';
    };
}
