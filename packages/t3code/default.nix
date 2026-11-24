{
  lib,
  stdenvNoCC,
  fetchurl,
  appimageTools,
  undmg,
  bun,
  updateScriptZod,
}:

let
  pname = "t3code";
  version = "0.1.12-nightly.20261124.5178";

  # Nightly GitHub prereleases: the Linux AppImage name is unversioned, while the
  # macOS DMGs follow T3-Code-<version>-<arch>.dmg. The tag path pins each asset.
  sources = {
    "x86_64-linux" = {
      asset = "T3-Code-Nightly-x86_64.AppImage";
      hash = "sha256-/AKr0RL833PPYENbog65FoRkjNICOxpK6kulmGHzZv4=";
    };
    "aarch64-darwin" = {
      asset = "T3-Code-${version}-arm64.dmg";
      hash = "sha256-vKjuqtXqdmUCmiYixapHntceiPUVp/Xn54+RAnCyEAo=";
    };
    "x86_64-darwin" = {
      asset = "T3-Code-${version}-x64.dmg";
      hash = "sha256-UOL8CAUGQ/yzwCQRtbfC2yCpITo221cnAUtKo90674k=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/${source.asset}";
    hash = source.hash;
  };

  meta = {
    description = "Nightly desktop GUI for AI coding agents";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3code";
    platforms = builtins.attrNames sources;
  };

  passthru = {
    updateScript = [
      (lib.getExe bun)
      "${../..}/packages/t3code/update.ts"
      "${updateScriptZod}/index.js"
    ];
  };
in
if stdenvNoCC.hostPlatform.isLinux then
  let
    extracted = appimageTools.extract {
      inherit pname version src;
    };
  in
  appimageTools.wrapType2 {
    inherit
      pname
      version
      src
      meta
      ;
    extraPkgs = pkgs: [ pkgs.libsecret ];
    passthru = passthru // {
      extracted = extracted;
    };
  }
else
  stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      src
      meta
      passthru
      ;

    nativeBuildInputs = [ undmg ];
    sourceRoot = ".";
    dontBuild = true;
    # Keep the notarized bundle byte-for-byte intact; generic fixup rewrites
    # executable scripts inside Electron resources and invalidates its signature.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -R "T3 Code (Nightly).app" "$out/Applications/"
      ln -s "$out/Applications/T3 Code (Nightly).app/Contents/MacOS/T3 Code (Nightly)" "$out/bin/t3code"

      runHook postInstall
    '';
  }
