{
  appimageTools ? null,
  fetchurl,
  lib,
  stdenvNoCC,
  packageUpdater,
}:
let
  version = "0.10.2";
  # Release asset and hash for each supported platform.
  artifacts = {
    "x86_64-linux" = {
      asset = "Handy_${version}_amd64.AppImage";
      hash = "sha256-F8XxpKM/nExcI0oITMCq92bzpbYmYuAtcOURYYAKzhc=";
    };
    "aarch64-darwin" = {
      asset = "Handy_aarch64.app.tar.gz";
      hash = "sha256-aSKZJSLmeSV8QyY7KVDy2YW5yrNbDeI7FzQMRvZ/Yxw=";
    };
  };
  # Every platform's fetch, so one host can refresh all hashes.
  sources = lib.mapAttrs (
    _system: artifact:
    fetchurl {
      url = "https://github.com/cjpais/Handy/releases/download/v${version}/${artifact.asset}";
      hash = artifact.hash;
    }
  ) artifacts;
  finalAttrs = {
    pname = "handy";
    version = version;
    src = sources.${stdenvNoCC.hostPlatform.system};
    passthru = {
      sources = sources;
      updateScript = packageUpdater.script {
        attr = "handy";
        file = ./default.nix;
        nixUpdateArgs = [ "--use-github-releases" ];
      };
    };
    meta = {
      description = "Offline speech-to-text application";
      homepage = "https://handy.computer";
      license = lib.licenses.mit;
      mainProgram = "handy";
      platforms = builtins.attrNames artifacts;
    };
  };
  contents =
    if stdenvNoCC.hostPlatform.isLinux then
      appimageTools.extract (
        finalAttrs
        // {
          # The AppImage's linuxdeploy hook forces X11, preventing layer-shell on Niri.
          postExtract = ''
            substituteInPlace "$out/apprun-hooks/linuxdeploy-plugin-gtk.sh" \
              --replace-fail 'export GDK_BACKEND=x11' 'export GDK_BACKEND=wayland'
          '';
        }
      )
    else
      null;
in
if stdenvNoCC.hostPlatform.isLinux then
  appimageTools.wrapAppImage (
    finalAttrs
    // {
      contents = contents;
      passthru = finalAttrs.passthru // {
        src = finalAttrs.src;
      };
      extraPkgs = pkgs: [
        pkgs.libsecret
        pkgs.libpulseaudio
        pkgs.libayatana-appindicator
        pkgs.libgpg-error
        pkgs.wayland
      ];
      extraInstallCommands = ''
        install -Dm644 ${contents}/Handy.desktop "$out/share/applications/handy.desktop"
        substituteInPlace "$out/share/applications/handy.desktop" --replace-fail 'Exec=handy' "Exec=$out/bin/handy"
        cp -r ${contents}/usr/share/icons "$out/share/"
      '';
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
        cp -R Handy.app "$out/Applications/"
        ln -s "$out/Applications/Handy.app/Contents/MacOS/handy" "$out/bin/handy"
        runHook postInstall
      '';
    }
  )
