{ inputs, ... }:
{
  config.flake.modules.homeManager.codingOpenCode =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      opencode-bin = "${pkgs.opencode}/bin/opencode";
      archOpsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.arch-ops-server;
      context7TokenPath = "${config.home.homeDirectory}/.config/agent-mcp/context7-token";
      githubTokenPath = "${config.home.homeDirectory}/.config/agent-mcp/github-token";

      # Bare `opencode` attaches to the running service with the current
      # directory. Any subcommand is passed through to the real binary.
      opencode-wrapper = pkgs.writeShellScriptBin "opencode" ''
        if [ $# -gt 0 ]; then
          exec ${opencode-bin} "$@"
        fi
        exec ${opencode-bin} attach http://localhost:4096 --dir "$PWD"
      '';

      # OpenCode's native MCP schema uses command arrays and supports file
      # interpolation for local-server environment variables.
      opencodeMcpServers = {
        arch-ops = {
          type = "local";
          command = [ (lib.getExe archOpsPackage) ];
          enabled = true;
        };
        context7 = {
          type = "local";
          command = [ (lib.getExe pkgs.context7-mcp) ];
          environment.CONTEXT7_API_KEY = "{file:${context7TokenPath}}";
          enabled = true;
        };
        github = {
          type = "local";
          command = [
            (lib.getExe pkgs.github-mcp-server)
            "stdio"
          ];
          environment.GITHUB_PERSONAL_ACCESS_TOKEN = "{file:${githubTokenPath}}";
          enabled = true;
        };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        nixos = {
          type = "local";
          command = [ (lib.getExe pkgs.mcp-nixos) ];
          enabled = true;
        };
      };
    in
    lib.mkMerge [
      {
        # Keep OpenCode's MCP config explicit in its own native schema.
        programs.opencode = {
          enable = true;
          package = opencode-wrapper;
          settings.mcp = opencodeMcpServers;
        };
      }

      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        # OpenCode headless server, started after the Linux graphical session.
        systemd.user.services.opencode-web = {
          Unit = {
            Description = "Shared OpenCode backend";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${opencode-bin} serve";
            Restart = "always";
            RestartSec = "2";
            WorkingDirectory = "%h";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })

      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        launchd.agents.opencode-web = {
          enable = true;
          config = {
            ProgramArguments = [
              opencode-bin
              "serve"
            ];
            KeepAlive = true;
            RunAtLoad = true;
            WorkingDirectory = config.home.homeDirectory;
          };
        };
      })
    ];
}
