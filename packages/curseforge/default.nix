{
  appimageTools,
  fetchurl,
  lib,
  packageUpdater,
}:

let
  finalAttrs = {
    pname = "curseforge";
    # Upstream versions carry a separate build number, as in CurseForge-<version>-<build>.AppImage.
    version = "1.328.0-43478";

    src = fetchurl {
      url = "https://curseforge.overwolf.com/electron/linux/CurseForge-${finalAttrs.version}.AppImage";
      hash = "sha256-OSG5vHmY654luaHC+0gKb0Bdjxnn012z+rGqX5MX40w=";
    };

    passthru = rec {
      # The Electron update feed names the current version and build.
      updateScript = packageUpdater.script {
        attr = "curseforge";
        file = ./default.nix;
        latestVersion = "curl -fsS https://curseforge.overwolf.com/electron/linux/latest-linux.yml | sed -n 's/^version: //p'";
      };
      appimageContents = appimageTools.extract {
        pname = finalAttrs.pname;
        version = finalAttrs.version;
        src = finalAttrs.src;
      };
      extracted = appimageContents;
    };

    meta = {
      description = "Desktop client for managing CurseForge mods";
      homepage = "https://www.curseforge.com/download/app";
      license = lib.licenses.unfree;
      mainProgram = "curseforge";
      platforms = [ "x86_64-linux" ];
    };
  };
in
appimageTools.wrapType2 finalAttrs
