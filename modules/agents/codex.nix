{ inputs, config, ... }:
let
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
      # Route Codex's built-in OpenAI provider through the local OpenCodex proxy.
      openai_base_url = "http://127.0.0.1:10100/v1";
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
  config.flake.modules.darwin.agentCodex =
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

  config.flake.modules.nixos.agentCodex =
    { pkgs, lib, ... }:
    {
      # System-level Codex defaults shared by the CLI, app, and IDE extension.
      environment.etc."codex/config.toml".source = mkCodexConfig {
        pkgs = pkgs;
        lib = lib;
      };
    };

  config.flake.modules.homeManager.agentCodex =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      codexHome = "${config.home.homeDirectory}/.codex";
      opencodexPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencodex;
      # On Linux, use the pinned package from packages/codex. On macOS, OpenAI
      # publishes the official binary via the Homebrew cask installed by
      # darwin.agentCodex; reference that path directly so the wrapper below still
      # applies the token bridge without introducing a second codex binary.
      codexExec =
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.lib.getExe (pkgs.callPackage ../../packages/codex { })
        else
          "/opt/homebrew/bin/codex";
      opencodeAuthPath = "${config.home.homeDirectory}/.local/share/opencode/auth.json";
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

    in
    {
      imports = [
        inputs.codex-desktop-linux.homeManagerModules.default
      ];

      config = lib.mkMerge [
        {
          home.packages = [
            codex
            opencodexPackage
            pkgs.jq
          ];

          home.file.".codex/.keep".text = "";
          home.file.".opencodex/.keep".text = "";
        }

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          # OpenAI does not publish a Linux Codex app yet; use the community
          # module and point it at the local CLI wrapper for graphical launches.
          programs.codexDesktopLinux = {
            enable = true;
            cliPackage = codex;
          };

          # Start the normal OpenCodex proxy for Codex CLI and the desktop app.
          systemd.user.services.opencodex = {
            Unit = {
              Description = "OpenCodex provider proxy";
              After = [ "network-online.target" ];
            };
            Service = {
              ExecStart = "${pkgs.lib.getExe opencodexPackage} start --port 10100";
              Restart = "on-failure";
              RestartSec = "5";
              WorkingDirectory = config.home.homeDirectory;
            };
            Install.WantedBy = [ "default.target" ];
          };

        })

        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          launchd.agents.opencodex = {
            enable = true;
            config = {
              ProgramArguments = [
                "${pkgs.lib.getExe opencodexPackage}"
                "start"
                "--port"
                "10100"
              ];
              KeepAlive = true;
              RunAtLoad = true;
              WorkingDirectory = config.home.homeDirectory;
            };
          };
        })
      ];
    };
}
