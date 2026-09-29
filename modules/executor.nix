{ inputs, ... }:
{
  config.flake.modules.homeManager.executor =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;
      bitwardenSecretTools =
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.bitwarden-secret-tools;
      agentBrowserPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      codeburnPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.codeburn;
      executorDataDirectory = "${config.home.homeDirectory}/.executor";
      agentBrowserProxyPort = 4790;
      # Executor stdio MCP is still per-call (spawn, initialize, close). Each
      # new agent-browser process re-attaches over CDP and Brave asks again to
      # allow remote debugging. Remote MCP is pooled, so keep one stdio child
      # behind mcp-proxy and point Executor at that HTTP endpoint.
      # Do not bake a CDP WebSocket UUID: --auto-connect rediscovers Brave.
      agentBrowserProxy = pkgs.writeShellScript "executor-agent-browser-mcp-proxy" ''
        set -eu
        exec ${lib.getExe pkgs.mcp-proxy} \
          --host 127.0.0.1 \
          --port ${toString agentBrowserProxyPort} \
          --transport streamablehttp \
          --no-stateless \
          -e HOME ${config.home.homeDirectory} \
          -e AGENT_BROWSER_AUTO_CONNECT 1 \
          -e AGENT_BROWSER_IDLE_TIMEOUT_MS 0 \
          -e AGENT_BROWSER_SESSION executor \
          -- ${lib.getExe agentBrowserPackage} \
            --auto-connect \
            --session executor \
            --idle-timeout 0 \
            mcp
      '';

      # Load API tokens at MCP startup so they never enter Executor's saved config.
      # Runtime Bitwarden items share a generic prefix; the remaining name
      # identifies the service and credential purpose for any consumer.
      # The generated Bitwarden manifest declares each item's output mode.
      mcpServers = [
        {
          slug = "arch-ops";
          name = "Arch Linux operations";
          description = "MCP server for Arch Linux package and documentation operations.";
          transport = "stdio";
          command = lib.getExe archOpsPackage;
          args = [ ];
        }
        {
          slug = "codeburn";
          name = "CodeBurn";
          description = "Local coding-agent usage and savings analytics.";
          transport = "stdio";
          command = lib.getExe codeburnPackage;
          args = [ "mcp" ];
        }
        {
          slug = "agent-browser";
          name = "Agent Browser";
          description = "Fast, persistent browser automation with a compact MCP tool profile.";
          transport = "remote";
          endpoint = "http://127.0.0.1:${toString agentBrowserProxyPort}/mcp";
          remoteTransport = "streamable-http";
        }
        {
          slug = "context7";
          name = "Context7";
          description = "Up-to-date library documentation and code examples.";
          transport = "stdio";
          command = "${bitwardenSecretTools}/bin/bw-secret";
          args = [
            "exec"
            "--item"
            "secret--context7--api-key"
            "--"
            (lib.getExe pkgs.context7-mcp)
          ];
        }
        {
          slug = "github";
          name = "GitHub";
          description = "GitHub repositories, pull requests, issues, and workflows.";
          transport = "stdio";
          command = "${bitwardenSecretTools}/bin/bw-secret";
          args = [
            "exec"
            "--item"
            "secret--github--personal-access-token"
            "--"
            (lib.getExe pkgs.github-mcp-server)
            "stdio"
          ];
        }
        {
          slug = "postgres_sql_mcp";
          name = "Postgres SQL MCP";
          description = "Read-only PostgreSQL database access through pgEdge MCP.";
          transport = "stdio";
          command = lib.getExe pkgs.docker;
          # Linux: Cursor/session-manager forwards bind 127.0.0.1, which
          # host.docker.internal (docker0) cannot reach. Host networking makes
          # 127.0.0.1 inside the container the same loopback. Darwin Docker
          # Desktop already maps host.docker.internal to the Mac localhost.
          args = [
            "run"
            "-i"
            "--rm"
          ]
          ++ (
            if pkgs.stdenv.hostPlatform.isLinux then
              [
                "--network"
                "host"
                "-e"
                "PGEDGE_DB_HOST=127.0.0.1"
              ]
            else
              [
                "--add-host"
                "host.docker.internal:host-gateway"
                "-e"
                "PGEDGE_DB_HOST=host.docker.internal"
              ]
          )
          ++ [
            "-e"
            "PGEDGE_DB_PORT"
            "-e"
            "PGEDGE_DB_NAME"
            "-e"
            "PGEDGE_DB_USER"
            "-e"
            "PGEDGE_DB_PASSWORD"
            "-e"
            "PGEDGE_DB_ALLOW_WRITES"
            "ghcr.io/pgedge/postgres-mcp:latest"
          ];
          # allow_writes is off unless the Executor connection sets
          # PGEDGE_DB_ALLOW_WRITES to true/1/yes; pgEdge defaults to false.
          envVars = [
            "PGEDGE_DB_PORT"
            "PGEDGE_DB_NAME"
            "PGEDGE_DB_USER"
            "PGEDGE_DB_PASSWORD"
            "PGEDGE_DB_ALLOW_WRITES"
          ];
          # The connection is intentionally created manually in Executor so
          # database credentials never get provisioned by Home Manager.
          createConnection = false;
        }
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        {
          slug = "nixos";
          name = "NixOS";
          description = "NixOS, Home Manager, Darwin, nixpkgs, and Nix docs via mcp-nixos.";
          transport = "stdio";
          command = lib.getExe pkgs.mcp-nixos;
          args = [ ];
        }
      ];

      declarations = (pkgs.formats.json { }).generate "executor-mcp-declarations.json" {
        servers = mcpServers;
      };

      executorDaemon = pkgs.writeShellScript "executor-daemon" ''
        set -eu
        mkdir -p ${lib.escapeShellArg "${executorDataDirectory}/logs"}
        exec ${lib.getExe executorPackage} daemon run --foreground --port 4789 --hostname 127.0.0.1
      '';

      executorSync = pkgs.writeShellApplication {
        name = "executor-sync";
        runtimeInputs = [
          pkgs.bun
          pkgs.coreutils
        ];
        text = ''
          export EXECUTOR_DATA_DIR=${lib.escapeShellArg executorDataDirectory}
          export EXECUTOR_DECLARATIONS=${lib.escapeShellArg declarations}
          export EXECUTOR_BIN=${lib.escapeShellArg (lib.getExe executorPackage)}
          export EXECUTOR_URL=http://127.0.0.1:4789
          for attempt in $(seq 1 60); do
            proxyStatus="$(${lib.getExe pkgs.curl} --silent --show-error --max-time 2 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:${toString agentBrowserProxyPort}/mcp || true)"
            if [ "$proxyStatus" = 200 ] || [ "$proxyStatus" = 406 ]; then
              break
            fi
            if [ "$attempt" -eq 60 ]; then
              printf 'Agent Browser MCP proxy did not become ready at 127.0.0.1:%s\n' ${toString agentBrowserProxyPort} >&2
              exit 1
            fi
            sleep 1
          done
          exec ${lib.getExe pkgs.bun} ${./executor/assets/sync.ts}
        '';
      };

      serviceEnvironment = {
        BW_SECRET_CONFIG = "${config.xdg.configHome}/bw-secret/secrets.json";
        EXECUTOR_SUPERVISED = "1";
        EXECUTOR_DATA_DIR = executorDataDirectory;
        EXECUTOR_SCOPE_DIR = executorDataDirectory;
        EXECUTOR_SERVICE_VERSION = executorPackage.version;
      };
    in
    {
      home.file.".executor/logs/.keep".text = "";

      home.packages = [
        agentBrowserPackage
        executorPackage
        executorSync
      ];

      # Keep one daemon alive for every client; its local database is outside
      # the Nix store, while executor-sync reconciles the desired MCP catalog.
      systemd.user.services.executor = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "Executor MCP integration daemon";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStart = "${executorDaemon}";
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") serviceEnvironment;
          Restart = "on-failure";
          RestartSec = "5";
          WorkingDirectory = config.home.homeDirectory;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.agent-browser-mcp-proxy = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "Persistent Agent Browser MCP proxy";
          After = [
            "graphical-session.target"
            "network-online.target"
          ];
        };
        Service = {
          ExecStart = "${agentBrowserProxy}";
          Restart = "always";
          RestartSec = "2";
          WorkingDirectory = config.home.homeDirectory;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.executor-mcp-sync = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "Reconcile Executor MCP declarations";
          Requires = [
            "executor.service"
            "agent-browser-mcp-proxy.service"
          ];
          After = [
            "executor.service"
            "agent-browser-mcp-proxy.service"
          ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe executorSync}";
        };
        Install.WantedBy = [ "default.target" ];
      };

      launchd.agents.executor = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = true;
        config = {
          ProgramArguments = [ "${executorDaemon}" ];
          EnvironmentVariables = serviceEnvironment;
          ProcessType = "Background";
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${executorDataDirectory}/logs/daemon.log";
          StandardErrorPath = "${executorDataDirectory}/logs/daemon.error.log";
        };
      };

      launchd.agents.agent-browser-mcp-proxy = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = true;
        config = {
          ProgramArguments = [ "${agentBrowserProxy}" ];
          ProcessType = "Background";
          RunAtLoad = true;
          KeepAlive = true;
          WorkingDirectory = config.home.homeDirectory;
          StandardOutPath = "${executorDataDirectory}/logs/agent-browser-mcp-proxy.log";
          StandardErrorPath = "${executorDataDirectory}/logs/agent-browser-mcp-proxy.error.log";
        };
      };

      launchd.agents.executor-mcp-sync = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = true;
        config = {
          ProgramArguments = [ (lib.getExe executorSync) ];
          ProcessType = "Background";
          RunAtLoad = true;
        };
      };
    };
}
