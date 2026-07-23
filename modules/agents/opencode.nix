{ inputs, ... }:
{
  config.flake.modules.homeManager.agentOpenCode =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      opencode-bin = "${pkgs.opencode}/bin/opencode";
      executorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.executor;

      # Bare `opencode` attaches to the running service with the current
      # directory. Any subcommand is passed through to the real binary.
      opencode-wrapper = pkgs.writeShellScriptBin "opencode" ''
        if [ $# -gt 0 ]; then
          exec ${opencode-bin} "$@"
        fi
        exec ${opencode-bin} attach http://localhost:4096 --dir "$PWD"
      '';

      # OpenCode connects once to Executor, which supplies the shared MCP catalog.
      opencodeMcpServers = {
        executor = {
          type = "local";
          command = [
            (lib.getExe executorPackage)
            "mcp"
          ];
          enabled = true;
        };
      };
    in
    {
      # Keep OpenCode's MCP config explicit in its own native schema.
      programs.opencode = {
        enable = true;
        package = opencode-wrapper;
        settings.mcp = opencodeMcpServers;
      };

      /*
        # OpenCode headless server, started after the Linux graphical session.
        systemd.user.services.opencode-web = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
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

        launchd.agents.opencode-web = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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
      */
    };
}
