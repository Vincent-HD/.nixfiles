{ ... }:
{
  # Home Manager: CurseForge desktop client (upstream AppImage wrapped for NixOS)
  config.flake.modules.homeManager.curseforge =
    { pkgs, ... }:
    let
      version = "1.312.1";
      build = "36055";
      src = pkgs.fetchurl {
        url = "https://curseforge.overwolf.com/electron/linux/CurseForge-${version}-${build}.AppImage";
        sha256 = "sha256-0o3L2hy2d1nuXktRElY3GnAjI85t3qOtt9/eXCoGNck=";
      };
      extracted = pkgs.appimageTools.extractType2 {
        pname = "curseforge";
        version = version;
        src = src;
      };
      curseforge = pkgs.appimageTools.wrapType2 {
        pname = "curseforge";
        version = version;
        src = src;
      };
    in
    {
      home.packages = [ curseforge ];

      # wrapType2 only exposes bin/curseforge — no .desktop, so KDE has no launcher/icon.
      # Icons and metadata come from the extracted AppImage (same as upstream curseforge.desktop).
      xdg.desktopEntries.curseforge = {
        name = "CurseForge";
        genericName = "CurseForge";
        comment = "The Easiest Way to Manage Your Mods";
        exec = "curseforge %U";
        icon = "${extracted}/usr/share/icons/hicolor/512x512/apps/curseforge.png";
        terminal = false;
        categories = [ "Utility" ];
        mimeType = [
          "x-scheme-handler/curseforge"
          "x-scheme-handler/cfauth"
          "x-scheme-handler/curseforge-checkout"
        ];
        settings = {
          StartupWMClass = "CurseForge";
          X-AppImage-Version = "${version}-${build}";
        };
      };
    };
}
