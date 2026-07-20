{ inputs, ... }:
{
  config.flake.modules.homeManager.agents =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      papercutsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.papercuts;
      context7TokenPath = "${config.home.homeDirectory}/.config/agent-mcp/context7-token";
      githubTokenPath = "${config.home.homeDirectory}/.config/agent-mcp/github-token";

      # Papercuts defaults to a macOS-specific path upstream; keep one XDG path
      # across both hosts and preserve an explicit caller override.
      papercuts = pkgs.writeShellScriptBin "papercuts" ''
        export PAPERCUTS_HOME="''${PAPERCUTS_HOME:-${config.xdg.dataHome}/papercuts}"
        exec ${lib.getExe papercutsPackage} "$@"
      '';

      # Cursor cannot interpolate raw token files into local MCP environments.
      # Keep the token out of generated JSON and fail before launching without it.
      cursorContext7Mcp = pkgs.writeShellScript "cursor-context7-mcp" ''
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

      cursorGithubMcp = pkgs.writeShellScript "cursor-github-mcp" ''
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

      # Cursor uses its documented global mcpServers JSON schema directly.
      cursorMcpServers = {
        arch-ops.command = lib.getExe archOpsPackage;
        context7.command = "${cursorContext7Mcp}";
        github.command = "${cursorGithubMcp}";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nixos.command = lib.getExe pkgs.mcp-nixos;
      };

      skillFiles = lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".agents/skills/${name}" {
          source = source;
        }
      ) config.custom.agentSetup.skills;

      papercutsInstructions = ''
        <!-- papercuts:begin v1 -->
        ## Papercuts

        - Proactively record small, concrete friction encountered while working.
        - Use one or two sentences: state what was being done, what got in the way, and optionally a suspected cause or fix.
        - Record each distinct issue at most once per task.
        - Never include secrets, raw transcripts, or large command output.
        - Keep using the project's normal issue workflow for bugs; Papercuts is a friction journal.
        - Pipe the observation to `papercuts add --stdin --source codex`.
        - Continue the primary task if capture fails, and never record that failure as another papercut.
        - Never review transcripts automatically.
        <!-- papercuts:end -->
      '';
    in
    {
      options.custom.agentSetup.skills = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
        default = { };
        description = ''
          Agent Skills installed once under the cross-client ~/.agents/skills standard.
          Codex, Cursor, and OpenCode discover this location natively.
        '';
      };

      config = {
        # Add a portable skill here once; all three agents discover the same directory.
        custom.agentSetup.skills = {
          context7-mcp = ./agents/assets/skills/context7-mcp;
          create-minecraft-schematic = ./agents/assets/skills/create-minecraft-schematic;
          design-minecraft-build = ./agents/assets/skills/design-minecraft-build;
          grill-me = ./agents/assets/skills/grill-me;
          papercuts = ./agents/assets/skills/papercuts;
          reference-repository = ./agents/assets/skills/reference-repository;
          rtk = ./agents/assets/skills/rtk;
        };

        home = {
          packages = [
            archOpsPackage
            papercuts
            pkgs.context7-mcp
            pkgs.github-mcp-server
            pkgs.rtk
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.mcp-nixos
          ];

          sessionVariables.PAPERCUTS_HOME = "${config.xdg.dataHome}/papercuts";

          file = skillFiles // {
            # Codex supports global instructions; Cursor receives the portable
            # Papercuts and RTK skills because it has no file-backed global rule.
            ".codex/AGENTS.md".text = ''
              ${papercutsInstructions}

              @${config.home.homeDirectory}/.codex/RTK.md
            '';
            ".codex/RTK.md".source = "${pkgs.rtk.src}/hooks/codex/rtk-awareness.md";

            # Cursor Agent reads this global path, unlike its VS Code-profile MCP file.
            ".cursor/mcp.json".source = (pkgs.formats.json { }).generate "cursor-mcp.json" {
              mcpServers = cursorMcpServers;
            };

            # Use the absolute package path because GUI-launched Cursor may not
            # inherit the Home Manager profile PATH, especially on macOS.
            ".cursor/hooks.json".source = (pkgs.formats.json { }).generate "cursor-hooks.json" {
              version = 1;
              hooks.preToolUse = [
                {
                  command = "${lib.getExe pkgs.rtk} hook cursor";
                  matcher = "Shell";
                }
              ];
            };
          };
        };
      };
    };
}
