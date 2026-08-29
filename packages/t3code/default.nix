{
  lib,
  stdenvNoCC,
  fetchurl,
  appimageTools,
  undmg,
  bun,
}:

let
  # Nightly GitHub prereleases; artifact names follow T3-Code-<version>-<arch>.<ext>.
  sources = {
    "x86_64-linux" = {
      arch = "x86_64";
      ext = "AppImage";
      hash = "sha256-qtpKc0+kyaDAzHqEyufCLSJHqPKro+ZH0JbktuxWSNI=";
    };
    "aarch64-darwin" = {
      arch = "arm64";
      ext = "dmg";
      hash = "sha256-k3da7S6o6VIjPcK3mEa4V2j3aRg9C31v9fIH7Ua2k/k=";
    };
    "x86_64-darwin" = {
      arch = "x64";
      ext = "dmg";
      hash = "sha256-SSUsRV50kp2FXIRyqtIgBjv4CMnkdCfcoE9c+dkKwUM=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};

  pname = "t3code";
  version = "0.0.36-nightly.20260828.1210";

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
      ./update.ts
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

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -R "T3 Code (Nightly).app" "$out/Applications/"
      ln -s "$out/Applications/T3 Code (Nightly).app/Contents/MacOS/T3 Code (Nightly)" "$out/bin/t3code"

      runHook postInstall
    '';
  }
