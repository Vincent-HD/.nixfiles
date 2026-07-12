{ ... }:
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

      # Bare `opencode` attaches to the running service with the current
      # directory. Any subcommand is passed through to the real binary.
      opencode-wrapper = pkgs.writeShellScriptBin "opencode" ''
        if [ $# -gt 0 ]; then
          exec ${opencode-bin} "$@"
        fi
        exec ${opencode-bin} attach http://localhost:4096 --dir "$PWD"
      '';

      opencodeSettings = builtins.fromJSON (builtins.readFile ./assets/opencode.jsonc);
      opencodeSettingsWithHome = lib.recursiveUpdate opencodeSettings {
        mcp.github.headers.Authorization = "Bearer {file:${config.home.homeDirectory}/.config/opencode/github-token}";
      };
      opencodeSettingsForPlatform =
        if pkgs.stdenv.hostPlatform.isDarwin then
          opencodeSettingsWithHome
          // {
            mcp = builtins.removeAttrs opencodeSettingsWithHome.mcp [
              "github"
              "nixos"
            ];
          }
        else
          opencodeSettingsWithHome;
    in
    lib.mkMerge [
      {
        home.packages = [ opencode-wrapper ];

        xdg.configFile."opencode/opencode.jsonc".source =
          (pkgs.formats.json { }).generate "opencode.jsonc"
            opencodeSettingsForPlatform;
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
