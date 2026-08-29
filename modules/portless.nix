{ inputs, config, ... }:
let
  username = config.flake.username;
in
{
  config.flake.modules.nixos.portless =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.portless;
      package = cfg.package;
      stateDirectory = if cfg.stateDir == null then "/home/${cfg.user}/.portless" else cfg.stateDir;
      serviceRunner = pkgs.writeShellApplication {
        name = "portless-service";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssl
        ];
        text = ''
          export HOME=${lib.escapeShellArg "/home/${cfg.user}"}
          export SUDO_USER=${lib.escapeShellArg cfg.user}
          portlessUid="$(${lib.getExe' pkgs.coreutils "id"} -u ${lib.escapeShellArg cfg.user})"
          portlessGid="$(${lib.getExe' pkgs.coreutils "id"} -g ${lib.escapeShellArg cfg.user})"
          export SUDO_UID="$portlessUid"
          export SUDO_GID="$portlessGid"
          export PORTLESS_STATE_DIR=${lib.escapeShellArg stateDirectory}
          export PORTLESS_PORT=${toString cfg.proxyPort}
          export PORTLESS_HTTPS=${if cfg.https then "1" else "0"}
          export PORTLESS_LAN=0
          export PORTLESS_WILDCARD=${if cfg.wildcard then "1" else "0"}
          export PORTLESS_SYNC_HOSTS=${if cfg.syncHosts then "1" else "0"}

          exec ${lib.getExe package} proxy start --foreground --skip-trust \
            ${if cfg.https then "--https" else "--no-tls"} \
            --port ${toString cfg.proxyPort} \
            --tld ${lib.escapeShellArg cfg.tld} ${lib.optionalString cfg.wildcard "--wildcard"}
        '';
      };
      # Brave/Chromium on Linux read ~/.pki/nssdb, not only the OpenSSL bundle.
      nssTrust = pkgs.writeShellApplication {
        name = "portless-trust-nss";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.nssTools
        ];
        text = ''
          ca=${lib.escapeShellArg "${stateDirectory}/ca.pem"}
          dbDir="$HOME/.pki/nssdb"
          if [ ! -f "$ca" ]; then
            echo "portless CA not found at $ca; skip NSS trust"
            exit 0
          fi
          mkdir -p "$dbDir"
          if [ ! -f "$dbDir/cert9.db" ]; then
            certutil -d "sql:$dbDir" -N --empty-password
          fi
          certutil -d "sql:$dbDir" -D -n portless >/dev/null 2>&1 || true
          certutil -d "sql:$dbDir" -A -t "C,," -n portless -i "$ca"
        '';
      };
    in
    {
      options.services.portless = {
        enable = lib.mkEnableOption "the Portless local development proxy";

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.portless;
          description = "Portless package used by the proxy service and installed system-wide.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = username;
          description = "User whose Portless state directory stores routes and certificates.";
        };

        stateDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Portless state directory; defaults to the configured user's ~/.portless.";
        };

        proxyPort = lib.mkOption {
          type = lib.types.port;
          default = 443;
          description = "Port on which the Portless proxy listens.";
        };

        https = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Serve HTTPS and redirect HTTP traffic from port 80.";
        };

        tld = lib.mkOption {
          type = lib.types.str;
          default = "localhost";
          description = "Top-level domain used for Portless route hostnames.";
        };

        wildcard = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow unregistered subdomains to fall back to a parent route.";
        };

        syncHosts = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allow the privileged proxy to maintain its /etc/hosts block.";
        };

        caCertificateFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Public Portless CA PEM to install into the NixOS trust store (OpenSSL,
            curl, p11-kit). The proxy still generates certs under stateDir; this is
            only the public CA. `portless trust` is skipped because it is not
            NixOS-aware. Copy a regenerated ~/.portless/ca.pem here and rebuild.
          '';
        };
      };

      config = lib.mkMerge [
        { services.portless.enable = true; }
        (lib.mkIf cfg.enable {
          # openssl/lsof: `portless doctor`. nssTools: NSS import for Brave.
          environment.systemPackages = [
            package
            pkgs.openssl
            pkgs.lsof
            pkgs.nssTools
          ];

          # Flake-pure trust: the PEM must be in the Nix store (host copies it).
          security.pki.certificateFiles = lib.optional (
            cfg.https && cfg.caCertificateFile != null
          ) cfg.caCertificateFile;

          # Keep the privileged proxy alive before development apps start. The
          # wrapper mirrors upstream's root-owned service while chowning state
          # files back to the configured user through SUDO_UID/SUDO_GID.
          systemd.services.portless = {
            description = "Portless local development proxy";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = lib.getExe serviceRunner;
              Restart = "on-failure";
              RestartSec = 2;
              KillSignal = "SIGTERM";
              TimeoutStopSec = 5;
            };
          };

          systemd.services.portless-trust-nss = {
            description = "Trust the Portless local CA in the user NSS database";
            after = [ "portless.service" ];
            wants = [ "portless.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = cfg.user;
              ExecStart = lib.getExe nssTrust;
            };
          };
        })
      ];
    };

  config.flake.modules.darwin.portless =
    {
      lib,
      pkgs,
      ...
    }:
    let
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.portless;
      stateDirectory = "/Users/${username}/.portless";
      serviceRunner = pkgs.writeShellApplication {
        name = "portless-service";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssl
        ];
        text = ''
          export HOME=${lib.escapeShellArg "/Users/${username}"}
          export SUDO_USER=${lib.escapeShellArg username}
          portlessUid="$(${lib.getExe' pkgs.coreutils "id"} -u ${lib.escapeShellArg username})"
          portlessGid="$(${lib.getExe' pkgs.coreutils "id"} -g ${lib.escapeShellArg username})"
          export SUDO_UID="$portlessUid"
          export SUDO_GID="$portlessGid"
          export PORTLESS_STATE_DIR=${lib.escapeShellArg stateDirectory}
          export PORTLESS_PORT=443
          export PORTLESS_HTTPS=1
          export PORTLESS_LAN=0
          export PORTLESS_WILDCARD=0
          export PORTLESS_SYNC_HOSTS=1

          exec ${lib.getExe package} proxy start --foreground --skip-trust --https \
            --port 443 \
            --tld localhost
        '';
      };
    in
    {
      environment.systemPackages = [
        package
        pkgs.openssl
        pkgs.lsof
      ];

      # Portless starts with --skip-trust; install the live CA into the System
      # keychain at activation so browsers trust https://*.localhost.
      system.activationScripts.extraActivation.text = lib.mkAfter ''
        ca=${lib.escapeShellArg "${stateDirectory}/ca.pem"}
        if [ -f "$ca" ]; then
          security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$ca" || true
        fi
      '';

      # Portless's upstream macOS service is a root LaunchDaemon so it can
      # bind :443/:80 and update /etc/hosts before the user logs in.
      launchd.daemons.portless = {
        command = "${serviceRunner}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${stateDirectory}/service.log";
          StandardErrorPath = "${stateDirectory}/service.log";
        };
      };
    };
}
