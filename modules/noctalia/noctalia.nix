{ inputs, ... }:
{
  # NixOS: services Noctalia widgets expect (battery, power profiles).
  config.flake.modules.nixos.noctalia =
    { ... }:
    {
      services.power-profiles-daemon.enable = true;
      services.upower.enable = true;
    };

  # Home Manager: Noctalia v5 shell (from upstream flake homeModules.default).
  #
  # Noctalia v5 is a fresh rewrite with a TOML config format; v4 JSON settings
  # are not migrated automatically. The bar layout below is a best-effort v5
  # approximation of the previous v4 widgets. Plugins (e.g. screen-toolkit) are
  # not carried over because the v5 plugin system is experimental and uses a
  # different manifest format.
  config.flake.modules.homeManager.noctalia =
    { config, ... }:
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      programs.noctalia = {
        enable = true;

        settings = {
          shell = {
            avatar_path = "/home/${config.home.username}/.face";
            font_family = "Sans Serif";
            telemetry_enabled = true;
            panel.borders = true;
          };

          # The default [bar.main] already floats (marginEnds/marginEdge), so we
          # only override the widget lists here.
          bar.main = {
            start = [ "control-center" "workspaces" ];
            center = [ "active_window" ];
            end = [ "output_volume" "input_volume" "network" "clock" "tray" ];
          };

          widget = {
            active_window.max_length = 250;
            clock.format = "{:%H:%M}";
          };

          theme = {
            mode = "dark";
            source = "builtin";
            builtin = "Gruvbox";
          };

          wallpaper = {
            enabled = false;
            directory = "/home/${config.home.username}/Pictures/Wallpapers";
          };

          location.auto_locate = false;

          idle = {
            behavior = {
              lock = {
                enabled = false;
                timeout = 0;
                command = "noctalia:session lock";
              };
              "screen-off" = {
                enabled = true;
                timeout = 300;
                command = "noctalia:dpms-off";
                resume_command = "noctalia:dpms-on";
              };
            };
          };
        };
      };
    };
}
