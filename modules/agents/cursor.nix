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
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;

      # Keep Cursor's hook on the same test-free rtk build as the common agent setup.
      rtk = pkgs.rtk.overrideAttrs (_previousAttrs: {
        doCheck = false;
      });

      # Cursor connects once to Executor; its upstream MCP catalog is shared.
      cursorMcpServers = {
        executor = {
          command = lib.getExe executorPackage;
          args = [ "mcp" ];
        };
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
        # RTK rewrite hook disabled: on this host it can stall Cursor agent
        # Shell (preToolUse stdin) even on 3.15.6. Re-enable after Cursor 3.16
        # unsandboxed spawn is fixed.
        ".cursor/hooks.json".source = (pkgs.formats.json { }).generate "cursor-hooks.json" {
          version = 1;
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
