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
  # Nightly GitHub prereleases; artifact names follow T3-Code-<version>-<arch>.<ext>.
  sources = {
    "x86_64-linux" = {
      arch = "x86_64";
      ext = "AppImage";
      hash = "sha256-orO0UXpPKmc+cCCh5wbQePrIkcOj++5MMA6KPFGWkIk=";
    };
    "aarch64-darwin" = {
      arch = "arm64";
      ext = "dmg";
      hash = "sha256-XtqoR0MPiTfcOeGuqNbZZvMNmXrMSC2g+0A0+0FVUEc=";
    };
    "x86_64-darwin" = {
      arch = "x64";
      ext = "dmg";
      hash = "sha256-VHyPTzSUcYaoYycIOqnPYgQuHamF5jw4rxS8aEF/7So=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};

  pname = "t3code";
  version = "0.1.7-nightly.20261031.3991";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-${source.arch}.${source.ext}";
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
