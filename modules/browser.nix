{ ... }:
{
  # Home Manager side: web browser
  config.flake.modules.homeManager.browser =
    { pkgs, lib, ... }:
    let
      # chrome://inspect/#remote-debugging is session-only and does not survive a
      # Brave restart. Keep a localhost CDP port on every launch so Agent Browser
      # `--auto-connect` can rediscover it. nixpkgs only forwards commandLineArgs
      # on Linux; the Homebrew cask on Darwin still needs a manual inspect toggle.
      brave = pkgs.brave.override {
        commandLineArgs = "--remote-debugging-port=9222 --remote-allow-origins=*";
      };
    in
    {
      home.packages = [
        brave
      ];

      # Cursor runs terminals inside an FHS sandbox that includes its own Google Chrome
      # and hides the host Brave desktop entry; make CLI URL openers use Brave explicitly.
      home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        BROWSER = lib.getExe brave;
      };

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
