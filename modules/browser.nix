{ ... }:
{
  # Home Manager side: web browser
  config.flake.modules.homeManager.browser =
    { pkgs, ... }:
    let
      # Chromium 146.x is the last line that keeps VA-API working here.
      braveVideoArgs = "--enable-global-vaapi-lock";

      braveWithVaapi =
        (pkgs.brave.override {
          enableVideoAcceleration = false;
          commandLineArgs = braveVideoArgs;
        }).overrideAttrs
          (previousAttrs: {
            version = "1.88.138";
            src = pkgs.fetchurl {
              url = "https://github.com/brave/brave-browser/releases/download/v1.88.138/brave-browser_1.88.138_amd64.deb";
              hash = "sha256-Z1cXDihjzrVTj9XsG9ral8NMZSdPqL4q8VIZ2Ee05Qc=";
            };

            meta = previousAttrs.meta // {
              changelog = "https://github.com/brave/brave-browser/releases/tag/v1.88.138";
            };
          });
    in
    {
      home.packages = [
        braveWithVaapi
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
