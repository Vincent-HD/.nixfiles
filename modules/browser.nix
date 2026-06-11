{ ... }:
{
  # Home Manager side: web browser
  config.flake.modules.homeManager.browser =
    { pkgs, lib, ... }:
    {
      home.packages = [
        pkgs.brave
      ];

      # Default browser for xdg-open (editors, Cursor links, etc.): use Brave from nixpkgs
      # (`brave-browser.desktop` / `com.brave.Browser.desktop` under brave/share/applications)
      # Force ownership of the generated mimeapps file so stale backup files do not block HM switches.
      xdg = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        configFile."mimeapps.list".force = true;
        mimeApps.enable = true;
        mimeApps.defaultApplications = {
          "text/html" = [ "brave-browser.desktop" ];
          "application/pdf" = [ "brave-browser.desktop" ];
          "x-scheme-handler/http" = [ "brave-browser.desktop" ];
          "x-scheme-handler/https" = [ "brave-browser.desktop" ];
        };
      };
    };
}
