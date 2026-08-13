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
      agentBrowserPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      executorDataDirectory = "${config.home.homeDirectory}/.executor";
      agentBrowserProxyPort = 4790;
      context7TokenPath = "${config.home.homeDirectory}/.config/agent-mcp/context7-token";
      githubTokenPath = "${config.home.homeDirectory}/.config/agent-mcp/github-token";

      # Executor starts these wrappers, so token values stay in sops-managed
      # files rather than its database or generated client configuration.
      context7Mcp = pkgs.writeShellScript "executor-context7-mcp" ''
        set -eu
        token_file=${lib.escapeShellArg context7TokenPath}
        if [ ! -r "$token_file" ]; then
          printf 'Context7 MCP token is not readable: %s\n' "$token_file" >&2
          exit 1
        fi
        CONTEXT7_API_KEY="$("${pkgs.coreutils}/bin/cat" "$token_file")"
        if [ -z "$CONTEXT7_API_KEY" ]; then
          printf 'Context7 MCP token is empty: %s\n' "$token_file" >&2
          exit 1
        fi
        export CONTEXT7_API_KEY
        exec ${lib.getExe pkgs.context7-mcp}
      '';

      githubMcp = pkgs.writeShellScript "executor-github-mcp" ''
        set -eu
        token_file=${lib.escapeShellArg githubTokenPath}
        if [ ! -r "$token_file" ]; then
          printf 'GitHub MCP token is not readable: %s\n' "$token_file" >&2
          exit 1
        fi
        GITHUB_PERSONAL_ACCESS_TOKEN="$("${pkgs.coreutils}/bin/cat" "$token_file")"
        if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
          printf 'GitHub MCP token is empty: %s\n' "$token_file" >&2
          exit 1
        fi
        export GITHUB_PERSONAL_ACCESS_TOKEN
        exec ${lib.getExe pkgs.github-mcp-server} stdio
      '';

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
          command = "${context7Mcp}";
          args = [ ];
        }
        {
          slug = "github";
          name = "GitHub";
          description = "GitHub repositories, pull requests, issues, and workflows.";
          transport = "stdio";
          command = "${githubMcp}";
          args = [ ];
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
          description = "NixOS package and option documentation.";
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
