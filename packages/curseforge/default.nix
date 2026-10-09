{
  appimageTools,
  bun,
  fetchurl,
  lib,
}:

let
  finalAttrs = {
    pname = "curseforge";
    version = "1.322.0";

    # Upstream AppImage filenames include a separate build number.
    build = "40357";

    src = fetchurl {
      url = "https://curseforge.overwolf.com/electron/linux/CurseForge-${finalAttrs.version}-${finalAttrs.build}.AppImage";
      hash = "sha256-8EPXYdjSVg/UMywIeTxeyyZh8Smm9fiBiRHb9zbmamE=";
    };

    passthru = rec {
      build = finalAttrs.build;
      updateScript = [
        (lib.getExe bun)
        ./update.ts
      ];
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
