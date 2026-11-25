{ config, ... }:
let
  username = config.flake.username;
in
{
  # Home Manager side: Spotifast, the lightweight native Spotify client from nixpkgs.
  # Playback needs Spotify Premium. The built-in player tops out at 320 kbps.
  config.flake.modules.homeManager.spotifast =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.spotifast ];
    };

  config.flake.modules.nixos.spotifast =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      lan = config.custom.spotifast.lan;
      interface = lib.escapeShellArg lan.interface;
      subnet = lib.escapeShellArg lan.ipv4Subnet;
      refreshPorts = pkgs.writeShellApplication {
        name = "soloist-firewall";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.iproute2
          pkgs.ipset
        ];
        text = builtins.readFile ./assets/soloist-firewall.sh;
      };
    in
    {
      options.custom.spotifast.lan = {
        interface = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "Trusted LAN interface used for Spotify Connect.";
        };
        ipv4Subnet = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "Trusted IPv4 CIDR used for Spotify Connect.";
        };
      };

      config = {
        assertions = [
          {
            assertion = config.networking.firewall.enable && config.networking.firewall.backend == "iptables";
            message = "The Spotifast LAN rules require the NixOS iptables firewall.";
          }
        ];

        # Scope Avahi's shared mDNS port to the LAN.
        services.avahi.openFirewall = false;

        # Accept pairing traffic only for ports tracked in the live ipset.
        networking.firewall = {
          extraPackages = [ pkgs.ipset ];
          extraCommands = ''
            ipset -exist create soloist-connect bitmap:port range 1-65535 timeout 5
            iptables -w -A nixos-fw -i ${interface} -s ${subnet} -p udp --dport 5353 -j nixos-fw-accept
            ip6tables -w -A nixos-fw -i ${interface} -s fe80::/10 -p udp --dport 5353 -j nixos-fw-accept
            iptables -w -A nixos-fw -i ${interface} -s ${subnet} -p tcp -m set --match-set soloist-connect dst -j nixos-fw-accept
          '';
          extraStopCommands = ''
            if ipset list -n soloist-connect >/dev/null 2>&1; then
              ipset flush soloist-connect
            fi
          '';
        };

        # Refresh active listeners and let the kernel expire stale entries.
        systemd.services.soloist-firewall = {
          description = "Track Spotify Soloist's LAN pairing port";
          wantedBy = [ "firewall.service" ];
          after = [ "firewall.service" ];
          bindsTo = [ "firewall.service" ];
          partOf = [ "firewall.service" ];
          environment = {
            SPOTIFAST_USER = username;
            SPOTIFAST_STATE = "${config.home-manager.users.${username}.xdg.stateHome}/spotifast";
          };
          serviceConfig = {
            ExecStart = lib.getExe refreshPorts;
            Restart = "on-failure";
            RestartSec = "3s";
            CapabilityBoundingSet = [
              # ss needs to traverse the desktop user's /proc/PID/fd directories.
              "CAP_DAC_READ_SEARCH"
              "CAP_NET_ADMIN"
              "CAP_SYS_PTRACE"
            ];
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
          };
        };
      };
    };
}
