{ ... }:
{
  # Home Manager: Thunar graphical file manager
  config.flake.modules.homeManager.thunar =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.thunar ];

      # Open directories from xdg-open and other desktop applications in Thunar.
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory" = [ "thunar.desktop" ];
        };
      };
    };
}
