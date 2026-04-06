{ ... }:
{
  # Home Manager side: web browser
  flake.modules.homeManager.browser =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        brave
      ];

      # Default browser for xdg-open (editors, Cursor links, etc.): use Brave from nixpkgs
      # (`brave-browser.desktop` / `com.brave.Browser.desktop` under brave/share/applications)
      # Force ownership of the generated mimeapps file so stale backup files do not block HM switches.
      xdg.configFile."mimeapps.list".force = true;
      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = {
        "text/html" = [ "brave-browser.desktop" ];
        "application/pdf" = [ "brave-browser.desktop" ];
        "x-scheme-handler/http" = [ "brave-browser.desktop" ];
        "x-scheme-handler/https" = [ "brave-browser.desktop" ];
      };
    };
}
