{
  appimageTools,
  fetchurl,
}:

let
  finalAttrs = {
    pname = "curseforge";
    version = "1.312.1";

    # Upstream AppImage filenames include a separate build number.
    build = "36055";

    src = fetchurl {
      url = "https://curseforge.overwolf.com/electron/linux/CurseForge-${finalAttrs.version}-${finalAttrs.build}.AppImage";
      hash = "sha256-0o3L2hy2d1nuXktRElY3GnAjI85t3qOtt9/eXCoGNck=";
    };

    passthru = rec {
      build = finalAttrs.build;
      updateScript = ./update.sh;
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
