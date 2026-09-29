{ inputs, lib, ... }:
{
  # Home Manager: install Dankmail and start its tray UI hidden with the Niri session.
  config.flake.modules.homeManager.dankmail =
    { pkgs, ... }:
    let
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.dankmail;
    in
    {
      home.packages = [ package ];

      systemd.user.services.dmail = {
        Unit = {
          Description = "Dank Mail";
          Documentation = "https://github.com/arqueon/dankmail";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe package} run --hidden --shell-config ${package}/share/quickshell/dankmail";
          Restart = "on-failure";
          RestartSec = "2s";
          Slice = "app.slice";
          Environment = "PATH=${lib.makeBinPath [
            pkgs.libnotify
            pkgs.quickshell
            pkgs.systemd
            pkgs.xdg-utils
          ]}";
        };

        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
