{
  appimageTools ? null,
  bun,
  fetchurl,
  lib,
  stdenvNoCC,
  updateScriptZod,
}:

let
  sources = {
    "x86_64-linux" = {
      suffix = "-linux-x86_64.AppImage";
      hash = "sha256-T1CkDdHWLjInuRxsKzE0TfQSphAEvl5R1z3UAVh6TcY=";
    };
    "aarch64-darwin" = {
      suffix = "-macos-arm64.tar.gz";
      hash = "sha256-3s40Q1SK6Uie8kZmQNfeuk59RpaZoqkepyGnhlH1lDI=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};

  finalAttrs = rec {
    pname = "wifi-audio-streaming";
    version = "1.2.0";
    releaseTag = "v1.2";

    src = fetchurl {
      url = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/download/${finalAttrs.releaseTag}/WiFi-Audio-Streaming-${finalAttrs.version}${source.suffix}";
      hash = source.hash;
    };

    passthru = {
      updateScript = [
        (lib.getExe bun)
        ./update.ts
        "${updateScriptZod}/index.js"
      ];
    };

    meta = {
      description = "Stream audio between devices over a local network";
      homepage = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop";
      changelog = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/tag/${finalAttrs.releaseTag}";
      license = lib.licenses.eupl12;
      mainProgram = "wifi-audio-streaming";
      platforms = builtins.attrNames sources;
    };
  };
in
if stdenvNoCC.hostPlatform.isLinux then
  appimageTools.wrapType2 (
    finalAttrs
    // {
      extraPkgs = pkgs: [
        pkgs.libsecret
        pkgs.libpulseaudio
        pkgs.libappindicator-gtk3
      ];
    }
  )
else
  stdenvNoCC.mkDerivation (
    finalAttrs
    // {
      sourceRoot = ".";
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/Applications" "$out/bin"
        cp -R "WiFi Audio Streaming.app" "$out/Applications/"
        ln -s "$out/Applications/WiFi Audio Streaming.app/Contents/MacOS/WiFi Audio Streaming" "$out/bin/wifi-audio-streaming"

        runHook postInstall
      '';
    }
  )
