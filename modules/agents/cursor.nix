{ inputs, ... }:
{
  config.flake.modules.homeManager.agentCursor =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      context7TokenPath = "${config.home.homeDirectory}/.config/agent-mcp/context7-token";
      githubTokenPath = "${config.home.homeDirectory}/.config/agent-mcp/github-token";

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
    in
    {
      home.file = {
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

      xdg.configFile = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        # Cursor's Linux sandbox requires AppArmor support, which this host does not provide.
        "cursor/cli-config.json".text = builtins.toJSON {
          approvalMode = "allowlist";
          sandbox.mode = "disabled";
          version = 1;
        };
      };
    };
}
