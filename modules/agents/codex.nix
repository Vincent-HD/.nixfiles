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
      plannotatorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.plannotator;
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;
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

      # Executor is the single local MCP endpoint; it owns the upstream catalog.
      mcp_servers = {
        executor = {
          command = lib.getExe executorPackage;
          args = [ "mcp" ];
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
    let
      homeDirectory = "/Users/${config.flake.username}";
      opencodexPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencodex;
    in
    {
      # Install the official Codex CLI; the codex-app cask is deprecated upstream.
      homebrew.casks = [
        "codex"
      ];

      # System-level Codex defaults shared by the CLI, app, and IDE extension.
      environment.etc."codex/config.toml".source = mkCodexConfig {
        pkgs = pkgs;
        lib = lib;
      };

      # Match OpenCodex's native launchd label so its health checks recognize it.
      launchd.user.agents.opencodex = {
        command = "${pkgs.lib.getExe opencodexPackage} start --port 10100";
        environment.OCX_SERVICE = "1";
        serviceConfig = {
          Label = "com.opencodex.proxy";
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "${homeDirectory}/.opencodex/service.log";
          StandardErrorPath = "${homeDirectory}/.opencodex/service.log";
          WorkingDirectory = homeDirectory;
        };
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

          # Opt into Cursor's native tools only after OpenCodex owns the provider setup.
          home.activation.opencodexCursorNativeExec = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            config_directory="${config.home.homeDirectory}/.opencodex"
            config_path="$config_directory/config.json"

            if [ -f "$config_path" ] && ${lib.getExe pkgs.jq} -e '.providers.cursor? | type == "object"' "$config_path" > /dev/null; then
              config_tmp="$(${pkgs.coreutils}/bin/mktemp "$config_directory/config.json.XXXXXX")"
              trap 'rm -f "$config_tmp"' EXIT
              if ${lib.getExe pkgs.jq} '.providers.cursor.nativeLocalExec = "on"' "$config_path" > "$config_tmp"; then
                mv "$config_tmp" "$config_path"
              else
                exit 1
              fi
              trap - EXIT
            fi
          '';
        }

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          # OpenAI does not publish a Linux Codex app yet; use the community
          # module and point it at the local CLI wrapper for graphical launches.
          programs.codexDesktopLinux = {
            enable = true;
            cliPackage = codex;
          };

          # Match OpenCodex's native unit name so its health checks recognize it.
          systemd.user.services."opencodex-proxy" = {
            Unit = {
              Description = "OpenCodex provider proxy";
              After = [ "network-online.target" ];
            };
            Service = {
              ExecStart = "${pkgs.lib.getExe opencodexPackage} start --port 10100";
              Environment = "OCX_SERVICE=1";
              Restart = "on-failure";
              RestartSec = "5";
              WorkingDirectory = config.home.homeDirectory;
            };
            Install.WantedBy = [ "default.target" ];
          };

        })

      ];
    };
}
