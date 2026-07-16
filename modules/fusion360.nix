{ ... }:
{
  # Home Manager: Linux-only Autodesk Fusion runtime, launcher, and SSO callback.
  config.flake.modules.homeManager.fusion360 =
    { pkgs, ... }:
    let
      fusion360 = pkgs.callPackage ../packages/fusion360 { };
    in
    {
      home.packages = [ fusion360 ];

      xdg.desktopEntries = {
        fusion360 = {
          name = "Autodesk Fusion";
          genericName = "3D CAD, CAM, CAE, and PCB Design";
          comment = "Run Autodesk Fusion with the Nix-managed Wine runtime";
          exec = "fusion360 %U";
          icon = "applications-engineering";
          terminal = false;
          categories = [
            "Graphics"
            "Engineering"
          ];
          settings.StartupWMClass = "Fusion360.exe";
        };

        fusion360-adskidmgr = {
          name = "Autodesk Fusion Identity Manager";
          exec = "fusion360-uri-handler %u";
          terminal = false;
          mimeType = [ "x-scheme-handler/adskidmgr" ];
          settings.NoDisplay = "true";
        };
      };

      # Send Autodesk browser sign-in callbacks back into Fusion's Wine prefix.
      xdg.mimeApps = {
        enable = true;
        defaultApplications."x-scheme-handler/adskidmgr" = [
          "fusion360-adskidmgr.desktop"
        ];
      };
    };
}
