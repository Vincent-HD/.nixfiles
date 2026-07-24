{
  appimageTools,
  bun,
  fetchurl,
  lib,
  makeBinaryWrapper,
  stdenv,
  undmg,
}:

let
  packageName = "localsend";
  packageVersion = "1.17.0";
  sources = {
    appImage = "sha256-waHnvHu37r32w2WjDO8NS6Pmu3mWHDuU7fkYkg+ONvA=";
    dmg = "sha256-/fGkLuE+uf3WrpTcWIOYHooJWZ51i94j9uZ3xPq1yTw=";
  };
  packageUpdateScript = [
    (lib.getExe bun)
    ./update.ts
  ];

  linux =
    let
      finalAttrs = {
        pname = packageName;
        version = packageVersion;

        # Use the upstream Linux AppImage so Nix never builds LocalSend's Flutter application.
        src = fetchurl {
          url = "https://github.com/localsend/localsend/releases/download/v${finalAttrs.version}/LocalSend-${finalAttrs.version}-linux-x86-64.AppImage";
          hash = sources.appImage;
        };

        passthru = rec {
          appimageContents = appimageTools.extractType2 {
            pname = finalAttrs.pname;
            version = finalAttrs.version;
            src = finalAttrs.src;
          };
          extracted = appimageContents;
          updateScript = packageUpdateScript;
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
    appimageTools.wrapType2 finalAttrs;

  darwin = stdenv.mkDerivation (finalAttrs: {
    pname = packageName;
    version = packageVersion;

    # Use the upstream macOS DMG instead of building the Flutter application.
    src = fetchurl {
      url = "https://github.com/localsend/localsend/releases/download/v${finalAttrs.version}/LocalSend-${finalAttrs.version}.dmg";
      hash = sources.dmg;
    };

    nativeBuildInputs = [
      makeBinaryWrapper
      undmg
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications"
      cp -R LocalSend.app "$out/Applications"
      makeBinaryWrapper "$out/Applications/LocalSend.app/Contents/MacOS/LocalSend" "$out/bin/localsend"

      runHook postInstall
    '';

    passthru.updateScript = packageUpdateScript;

    meta = {
      description = "Open source cross-platform alternative to AirDrop";
      homepage = "https://localsend.org/";
      license = lib.licenses.mit;
      mainProgram = "localsend";
      platforms = [ "aarch64-darwin" ];
    };
  });
in
if stdenv.hostPlatform.isDarwin then darwin else linux
