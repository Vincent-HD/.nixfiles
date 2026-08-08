{
  appimageTools,
  bun,
  fetchurl,
  lib,
}:

let
  finalAttrs = {
    pname = "curseforge";
    version = "1.316.0";

    # Upstream AppImage filenames include a separate build number.
    build = "37372";

    src = fetchurl {
      url = "https://curseforge.overwolf.com/electron/linux/CurseForge-${finalAttrs.version}-${finalAttrs.build}.AppImage";
      hash = "sha256-ZH4ZkFSoT8bQgcQPkszcux4gds4DHwrD7Vyub+13mgQ=";
    };

    passthru = rec {
      build = finalAttrs.build;
      updateScript = [
        (lib.getExe bun)
        ./update.ts
      ];
      appimageContents = appimageTools.extractType2 {
        pname = finalAttrs.pname;
        version = finalAttrs.version;
        src = finalAttrs.src;
      };
      extracted = appimageContents;
    };

    meta = {
      description = "Desktop client for managing CurseForge mods";
      homepage = "https://www.curseforge.com/download/app";
      mainProgram = "curseforge";
      platforms = [ "x86_64-linux" ];
    };
  };
in
appimageTools.wrapType2 finalAttrs
