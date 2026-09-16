{
  alsa-lib,
  autoPatchelfHook,
  curl,
  fetchurl,
  fontconfig,
  freetype,
  jq,
  lib,
  libGL,
  libpulseaudio,
  libx11,
  libxext,
  libxi,
  libxrender,
  libxtst,
  makeWrapper,
  nix-update,
  stdenv,
  stdenvNoCC,
  writeShellScript,
  zlib,
}:

let
  # The vendor release API reports the current archive for every platform; read
  # the Linux entry and let nix-update rewrite the version and hash below.
  updateScript = writeShellScript "update-audiorelay" ''
    set -euo pipefail
    version="$(${lib.getExe curl} --fail --silent --show-error https://api.audiorelay.net/downloads | ${lib.getExe jq} -er '.linuxArchive.version')"
    exec ${lib.getExe nix-update} --flake audiorelay --version "$version"
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "audiorelay";
  version = "0.27.5";

  # Upstream ships a self-contained jpackage archive: the launcher in bin/, the
  # application jar and a full JRE under lib/.
  src = fetchurl {
    url = "https://dl.audiorelay.net/setups/linux/audiorelay-${finalAttrs.version}.tar.gz";
    hash = "sha256-xIVBOaS9Iee/eIGntuIevEz+gjKGeD1Pua1L9O346Mc=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Everything the launcher, the bundled JRE, and the runtime-extracted Skiko
  # renderer link against. Kernel interfaces such as glibc are dropped by
  # autoPatchelfHook, and the JRE libraries resolve inside the archive.
  buildInputs = [
    alsa-lib
    (lib.getLib fontconfig)
    freetype
    libGL
    libpulseaudio
    libx11
    libxext
    libxi
    libxrender
    libxtst
    stdenv.cc.cc.lib
    zlib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Keep the jpackage layout: the launcher resolves lib/ next to itself.
    mkdir -p "$out"
    cp --recursive bin lib "$out/"

    # The application jar unpacks libskiko-linux-x64.so into a temporary
    # directory at runtime, so autoPatchelfHook never sees its OpenGL, X11, and
    # fontconfig dependencies. Expose the build inputs to the dynamic loader.
    wrapProgram "$out/bin/AudioRelay" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}"

    runHook postInstall
  '';

  passthru.updateScript = [ updateScript ];

  meta = {
    description = "Stream audio between a desktop and an Android phone";
    homepage = "https://audiorelay.net/";
    license = lib.licenses.unfree;
    mainProgram = "AudioRelay";
    platforms = [ "x86_64-linux" ];
  };
})
