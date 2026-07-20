{ inputs, config, ... }:
let
  codexLbVersion = "1.21.0b3";
  codexLbHealthLiveUrl = "http://127.0.0.1:2455/health/live";
  codexLbHealthReadyUrl = "http://127.0.0.1:2455/health/ready";
  codexLbHealthStartupUrl = "http://127.0.0.1:2455/health/startup";
  mkCodexSettings =
    { pkgs, lib }:
    let
      homeDirectory =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "/Users/${config.flake.username}"
        else
          "/home/${config.flake.username}";
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      context7TokenPath = "${homeDirectory}/.config/agent-mcp/context7-token";
      githubTokenPath = "${homeDirectory}/.config/agent-mcp/github-token";

      # Codex cannot interpolate a token file into a local MCP environment.
      # Use fail-closed wrappers so secrets never enter the generated TOML.
      context7Mcp = pkgs.writeShellScript "codex-context7-mcp" ''
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

      githubMcp = pkgs.writeShellScript "codex-github-mcp" ''
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
      plannotatorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.plannotator;
    in
    {
      model = "gpt-5.5";
      model_provider = "codex-lb";
      model_reasoning_effort = "high";
      model_reasoning_summary = "concise";
      model_verbosity = "low";
      file_opener = "cursor";
      personality = "pragmatic";

      # Plannotator uses Codex's Stop lifecycle hook for automatic plan review.
      features.hooks = true;
      hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = lib.getExe plannotatorPackage;
              timeout = 345600;
              statusMessage = "Reviewing plan in Plannotator";
            }
          ];
        }
      ];

      model_providers.codex-lb = {
        name = "openai";
        base_url = "http://127.0.0.1:2455/backend-api/codex";
        wire_api = "responses";
        supports_websockets = true;
        requires_openai_auth = true;
      };

      # OpenCode Go exposes an OpenAI-compatible Responses endpoint. The API key
      # is exported by the Home Manager wrapper from OpenCode's own auth store.
      model_providers.opencode-go = {
        name = "OpenCode Go";
        base_url = "https://opencode.ai/zen/go/v1";
        env_key = "OPENCODE_API_KEY";
        env_key_instructions = "Run `opencode auth login --provider opencode-go`, or subscribe at https://opencode.ai/go and connect OpenCode Go.";
        wire_api = "responses";
        requires_openai_auth = false;
      };

      # Define Codex's native MCP TOML shape explicitly instead of normalizing
      # another client's schema through an intermediate registry.
      mcp_servers = {
        arch-ops = {
          command = lib.getExe archOpsPackage;
          enabled = true;
        };
        context7 = {
          command = "${context7Mcp}";
          enabled = true;
        };
        github = {
          command = "${githubMcp}";
          enabled = true;
        };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nixos = {
          command = lib.getExe pkgs.mcp-nixos;
          enabled = true;
        };
      };
    };

  mkCodexConfig =
    { pkgs, lib }:
    (pkgs.formats.toml { }).generate "codex-config.toml" (mkCodexSettings {
      pkgs = pkgs;
      lib = lib;
    });
in
{
  config.flake.modules.darwin.codex =
    { pkgs, lib, ... }:
    {
      # codex = CLI binary, codex-app = Codex.app desktop application.
      homebrew.casks = [
        "codex"
        "codex-app"
      ];

      # System-level Codex defaults shared by the CLI, app, and IDE extension.
      environment.etc."codex/config.toml".source = mkCodexConfig {
        pkgs = pkgs;
        lib = lib;
      };
    };

  config.flake.modules.nixos.codex =
    { pkgs, lib, ... }:
    {
      # System-level Codex defaults shared by the CLI, app, and IDE extension.
      environment.etc."codex/config.toml".source = mkCodexConfig {
        pkgs = pkgs;
        lib = lib;
      };
    };

  config.flake.modules.homeManager.codex =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      codexHome = "${config.home.homeDirectory}/.codex";
      codexLbHome = "${config.home.homeDirectory}/.codex-lb";
      # On Linux, use the pinned package from packages/codex. On macOS, OpenAI
      # publishes the official binary via the Homebrew cask installed by
      # darwin.codex; reference that path directly so the wrapper below still
      # applies the token bridge without introducing a second codex binary.
      codexExec =
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.lib.getExe (pkgs.callPackage ../packages/codex { })
        else
          "/opt/homebrew/bin/codex";
      opencodeAuthPath = "${config.home.homeDirectory}/.local/share/opencode/auth.json";
      # codex-lb upstream recommends uvx for non-Docker installs. Pin the PyPI
      # version here while keeping the runtime-managed virtualenv outside /nix/store.
      codex-lb = pkgs.writeShellScriptBin "codex-lb" ''
        set -euo pipefail

        mkdir -p "${codexLbHome}"
        export UV_CACHE_DIR="''${UV_CACHE_DIR:-${config.home.homeDirectory}/.cache/uv}"
        export UV_TOOL_DIR="''${UV_TOOL_DIR:-${config.home.homeDirectory}/.local/share/uv/tools}"
        exec ${pkgs.lib.getExe pkgs.uv} tool run --from codex-lb==${codexLbVersion} codex-lb "$@"
      '';

      # Bridge codex-lb's HTTP health probes into systemd's native readiness
      # and watchdog protocol. This mirrors upstream's Helm probes.
      codex-lb-watchdog = pkgs.replaceVarsWith {
        src = ./codex/assets/codex-lb-watchdog.sh;
        replacements = {
          codexLb = pkgs.lib.getExe codex-lb;
          curl = pkgs.lib.getExe pkgs.curl;
          livenessUrl = codexLbHealthLiveUrl;
          readinessUrl = codexLbHealthReadyUrl;
          startupUrl = codexLbHealthStartupUrl;
          systemdNotify = "${pkgs.systemd}/bin/systemd-notify";
        };
        name = "codex-lb-watchdog";
        isExecutable = true;
      };

      # Share the OpenCode Go API key with Codex without copying secrets into
      # Nix-managed files. OpenCode writes this credential after `/connect`.
      codexOpenCodeGoEnv = pkgs.writeShellScript "codex-opencode-go-env" ''
        if [ -r "${opencodeAuthPath}" ]; then
          if opencode_api_key="$(${pkgs.lib.getExe pkgs.jq} -er '."opencode-go".key // empty' "${opencodeAuthPath}" 2>/dev/null)"; then
            export OPENCODE_API_KEY="$opencode_api_key"
          fi
        fi
      '';

      # Keep the OpenCode Go credential bridge in the user-facing Codex wrapper.
      # MCP credentials are scoped to their own fail-closed server wrappers.
      codex = pkgs.lib.hiPrio (
        pkgs.writeShellScriptBin "codex" ''
          set -euo pipefail

          . ${codexOpenCodeGoEnv}

          exec ${codexExec} "$@"
        ''
      );

      codexLbEnvironment = {
        CODEX_LB_DATABASE_URL = "sqlite+aiosqlite:///${codexLbHome}/store.db";
        CODEX_LB_DATABASE_MIGRATE_ON_STARTUP = "true";
        CODEX_LB_DATABASE_SQLITE_PRE_MIGRATE_BACKUP_ENABLED = "true";
        CODEX_LB_DATABASE_SQLITE_PRE_MIGRATE_BACKUP_MAX_FILES = "5";
        CODEX_LB_DASHBOARD_AUTH_MODE = "standard";
        CODEX_LB_FIREWALL_TRUSTED_PROXY_CIDRS = "127.0.0.1/32,::1/128";
        CODEX_LB_OAUTH_REDIRECT_URI = "http://localhost:1455/auth/callback";
        CODEX_LB_OAUTH_CALLBACK_HOST = "127.0.0.1";
        CODEX_LB_OAUTH_CALLBACK_PORT = "1455";
        CODEX_LB_UPSTREAM_STREAM_TRANSPORT = "websocket";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        REQUESTS_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
    in
    {
      imports = [
        inputs.codex-desktop-linux.homeManagerModules.default
      ];

      config = lib.mkMerge [
        {
          home.packages = [
            codex
            codex-lb
            pkgs.jq
            pkgs.uv
          ];

          home.file.".codex/.keep".text = "";
          home.file.".codex-lb/.keep".text = "";
        }

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          # OpenAI does not publish a Linux Codex app yet; use the community
          # module and point it at the local CLI wrapper for graphical launches.
          programs.codexDesktopLinux = {
            enable = true;
            cliPackage = codex;
          };

          # Start the codex-lb dashboard/proxy for local Codex app-compatible clients.
          systemd.user.services.codex-lb = {
            Unit = {
              Description = "Codex account load balancer";
              After = [ "network-online.target" ];
              StartLimitIntervalSec = 300;
              StartLimitBurst = 5;
            };
            Service = {
              Type = "notify";
              ExecStart = codex-lb-watchdog;
              Environment = lib.mapAttrsToList (name: value: "${name}=${value}") codexLbEnvironment;
              LimitNOFILE = 65536;
              NotifyAccess = "all";
              Restart = "on-failure";
              RestartSec = "5";
              TimeoutStartSec = "90";
              WatchdogSec = "90";
              WorkingDirectory = codexLbHome;
            };
            Install.WantedBy = [ "default.target" ];
          };
        })

        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          launchd.agents.codex-lb = {
            enable = true;
            config = {
              ProgramArguments = [ "${pkgs.lib.getExe codex-lb}" ];
              EnvironmentVariables = codexLbEnvironment;
              KeepAlive = true;
              RunAtLoad = true;
              WorkingDirectory = codexLbHome;
            };
          };
        })
      ];
    };
}
