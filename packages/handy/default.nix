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
      asset = "Handy_0.10.0_amd64.AppImage";
      hash = "sha256-IGYcFrC54bfcUCC+Rj8rF/ZUv+rwuh1wMrxLd7Jo7Gw=";
    };
    "aarch64-darwin" = {
      asset = "Handy_aarch64.app.tar.gz";
      hash = "sha256-Ul5dNue2Bm6K8VVFVKh6y9D6Wgx+TE1IlOEPYx7Xnko=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
  finalAttrs = rec {
    pname = "handy";
    version = "0.10.0";
    src = fetchurl {
      url = "https://github.com/cjpais/Handy/releases/download/v${version}/${source.asset}";
      hash = source.hash;
    };
    passthru.updateScript = [
      (lib.getExe bun)
      "${../..}/packages/handy/update.ts"
      "${updateScriptZod}/index.js"
    ];
    meta = {
      description = "Offline speech-to-text application";
      homepage = "https://handy.computer";
      license = lib.licenses.mit;
      mainProgram = "handy";
      platforms = builtins.attrNames sources;
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
