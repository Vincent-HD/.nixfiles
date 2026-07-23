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
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      executorDataDirectory = "${config.home.homeDirectory}/.executor";
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

      mcpServers = [
        {
          slug = "arch-ops";
          name = "Arch Linux operations";
          description = "MCP server for Arch Linux package and documentation operations.";
          transport = "stdio";
          command = lib.getExe archOpsPackage;
          args = [ ];
          env = { };
        }
        {
          slug = "context7";
          name = "Context7";
          description = "Up-to-date library documentation and code examples.";
          transport = "stdio";
          command = "${context7Mcp}";
          args = [ ];
          env = { };
        }
        {
          slug = "github";
          name = "GitHub";
          description = "GitHub repositories, pull requests, issues, and workflows.";
          transport = "stdio";
          command = "${githubMcp}";
          args = [ ];
          env = { };
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
          env = { };
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
        runtimeInputs = [ pkgs.bun ];
        text = ''
          export EXECUTOR_DATA_DIR=${lib.escapeShellArg executorDataDirectory}
          export EXECUTOR_DECLARATIONS=${lib.escapeShellArg declarations}
          export EXECUTOR_BIN=${lib.escapeShellArg (lib.getExe executorPackage)}
          export EXECUTOR_URL=http://127.0.0.1:4789
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

      systemd.user.services.executor-mcp-sync = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "Reconcile Executor MCP declarations";
          Requires = [ "executor.service" ];
          After = [ "executor.service" ];
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
