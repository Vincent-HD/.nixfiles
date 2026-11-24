{
  appimageTools ? null,
  fetchurl,
  lib,
  stdenvNoCC,
  packageUpdater,
}:

let
  # Release tags drop the patch component (v1.2) while asset names pad it (1.2.0).
  version = "1.2";
  assetVersion = lib.versions.pad 3 version;

  # Release asset suffix and hash for each supported platform.
  artifacts = {
    "x86_64-linux" = {
      suffix = "-linux-x86_64.AppImage";
      hash = "sha256-T1CkDdHWLjInuRxsKzE0TfQSphAEvl5R1z3UAVh6TcY=";
    };
    "aarch64-darwin" = {
      suffix = "-macos-arm64.tar.gz";
      hash = "sha256-3s40Q1SK6Uie8kZmQNfeuk59RpaZoqkepyGnhlH1lDI=";
    };
  };
  # Every platform's fetch, so one host can refresh all hashes.
  sources = lib.mapAttrs (
    _system: artifact:
    fetchurl {
      url = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/download/v${version}/WiFi-Audio-Streaming-${assetVersion}${artifact.suffix}";
      hash = artifact.hash;
    }
  ) artifacts;

  finalAttrs = {
    pname = "wifi-audio-streaming";
    version = version;

    src = sources.${stdenvNoCC.hostPlatform.system};

    passthru = {
      sources = sources;
      updateScript = packageUpdater.script {
        attr = "wifi-audio-streaming";
        file = ./default.nix;
        nixUpdateArgs = [ "--use-github-releases" ];
      };
    };

    meta = {
      description = "Stream audio between devices over a local network";
      homepage = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop";
      changelog = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/tag/v${version}";
      license = lib.licenses.eupl12;
      mainProgram = "wifi-audio-streaming";
      platforms = builtins.attrNames artifacts;
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
