{ ... }:
{
  config.flake.modules.darwin.macosDefaults =
    { ... }:
    {
      system.defaults = {
        NSGlobalDomain.AppleInterfaceStyle = "Dark";

        dock = {
          autohide = true;
          tilesize = 64;
          wvous-br-corner = 14;
        };

        finder = {
          AppleShowAllFiles = true;
          FXPreferredViewStyle = "Nlsv";
          ShowPathbar = true;
          ShowStatusBar = false;
        };
      };
    };
}
