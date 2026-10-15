{
  lib,
  stdenvNoCC,
  fetchurl,
  appimageTools,
  undmg,
  bun,
  updateScriptZod,
  nix-update,
}:

let
  # Nightly GitHub prereleases; artifact names follow T3-Code-<version>-<arch>.<ext>.
  sources = {
    "x86_64-linux" = {
      arch = "x86_64";
      ext = "AppImage";
      hash = "sha256-pC090tH1awNsbl0v+mzZ6o2wwINRy8W4Z5DzSdT3Wb4=";
    };
    "aarch64-darwin" = {
      arch = "arm64";
      ext = "dmg";
      hash = "sha256-VJCe4uYe4gNcdGd0V+g7ZKPnBTC4exfVr8GvoPLg+4E=";
    };
    "x86_64-darwin" = {
      arch = "x64";
      ext = "dmg";
      hash = "sha256-8ExkD7/u9mUJoK63fJNcHsshSCBa3N24xkFtsDElM1o=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};

  pname = "t3code";
  version = "0.0.46-nightly.20261015.3158";

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
      (lib.getExe nix-update)
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
