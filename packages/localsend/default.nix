{
  appimageTools,
  fetchurl,
  lib,
}:

let
  finalAttrs = {
    pname = "localsend";
    version = "1.17.0";

    # Use the upstream Linux AppImage so Nix never builds LocalSend's Flutter application.
    src = fetchurl {
      url = "https://github.com/localsend/localsend/releases/download/v${finalAttrs.version}/LocalSend-${finalAttrs.version}-linux-x86-64.AppImage";
      hash = "sha256-waHnvHu37r32w2WjDO8NS6Pmu3mWHDuU7fkYkg+ONvA=";
    };

    passthru = rec {
      appimageContents = appimageTools.extractType2 {
        pname = finalAttrs.pname;
        version = finalAttrs.version;
        src = finalAttrs.src;
      };
      extracted = appimageContents;
    };

    extraInstallCommands = ''
      desktopFile="$(find ${finalAttrs.passthru.appimageContents} -name '*.desktop' -print -quit)"
      test -n "$desktopFile"
      install -Dm444 "$desktopFile" "$out/share/applications/localsend.desktop"
      substituteInPlace "$out/share/applications/localsend.desktop" \
        --replace 'Exec=AppRun' 'Exec=localsend' \
        --replace 'Exec=localsend_app' 'Exec=localsend'

      iconFile="$(find ${finalAttrs.passthru.appimageContents} -type f -name 'localsend*.png' -print | sort | tail -n 1)"
      if [ -n "$iconFile" ]; then
        install -Dm444 "$iconFile" "$out/share/icons/hicolor/512x512/apps/localsend.png"
      fi
    '';

    meta = {
      description = "Open source cross-platform alternative to AirDrop";
      homepage = "https://localsend.org/";
      license = lib.licenses.mit;
      mainProgram = "localsend";
      platforms = [ "x86_64-linux" ];
    };
  };
in
appimageTools.wrapType2 finalAttrs
