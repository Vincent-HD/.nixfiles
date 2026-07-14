{ ... }:
{
  # Home Manager: CurseForge desktop client (upstream AppImage wrapped for NixOS)
  config.flake.modules.homeManager.curseforge =
    { pkgs, ... }:
    let
      curseforge = pkgs.callPackage ../packages/curseforge { };
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
        icon = "${curseforge.passthru.extracted}/usr/share/icons/hicolor/512x512/apps/curseforge.png";
        terminal = false;
        categories = [ "Utility" ];
        mimeType = [
          "x-scheme-handler/curseforge"
          "x-scheme-handler/cfauth"
          "x-scheme-handler/curseforge-checkout"
        ];
        settings = {
          StartupWMClass = "CurseForge";
          X-AppImage-Version = "${curseforge.version}-${curseforge.passthru.build}";
        };
      };
    };
}
