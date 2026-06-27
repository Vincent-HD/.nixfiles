{ ... }:
{
  config.flake.modules.homeManager.noctalia-plugins-dependencies =
    { pkgs, ... }:
    let
      pluginSource = "https://github.com/noctalia-dev/noctalia-plugins";
    in
    {
      home.packages = [
        # screen-toolkit dependencies
        pkgs.curl
        pkgs.ffmpeg
        pkgs.gifski
        pkgs.grim
        pkgs.hyprpicker
        pkgs.imagemagick
        pkgs.kdePackages.kdialog
        pkgs.python3
        pkgs.python3Packages.pygobject3
        pkgs.slurp
        pkgs.tesseract
        pkgs.translate-shell
        pkgs.wf-recorder
        pkgs.wl-clipboard
        pkgs.zbar
        # end of screen-toolkit dependencies
      ];

      programs.noctalia-shell.plugins = {
        version = 2;
        sources = [
          {
            enabled = true;
            name = "Noctalia Plugins";
            url = pluginSource;
          }
        ];
        states.screen-toolkit = {
          enabled = true;
          sourceUrl = pluginSource;
        };
      };

      xdg.configFile."noctalia/plugins.json".force = true;

      # IMPORTANT: On NVIDIA GPUs, wl-screenrec fails with VAAPI errors.
      # The upstream plugin auto-detects recorders with:
      #   which wl-screenrec || which wf-recorder
      # so keeping wl-screenrec out of PATH forces wf-recorder, which is the
      # working software-encoded fallback on this machine.
    };
}
