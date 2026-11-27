{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  pipewire,
  fontconfig,
  freetype,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  packageUpdater,
}:

let
  # Release archive hash for each platform upstream CI builds.
  artifacts = {
    "x86_64-linux" = {
      arch = "x86_64";
      hash = "sha256-cnmLItRAt+//naAuq5VWTK2fyKUqiJktpqcOSCvrmwM=";
    };
    "aarch64-linux" = {
      arch = "aarch64";
      hash = "sha256-xDNt0iEiwwyn+tZ4hmHhIzpLYgmbs5BxncrGPukR0NA=";
    };
  };

  # Libraries the GUI loads with dlopen at runtime, which autoPatchelfHook cannot see.
  runtimeLibraries = [
    libxkbcommon
    vulkan-loader
    wayland
    libx11
    libxcb
    libxcursor
    libxi
    libxrandr
    fontconfig
    freetype
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tuyau";
  version = "0.1.0";

  src = finalAttrs.passthru.sources.${stdenv.hostPlatform.system};

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    pipewire
  ]
  ++ runtimeLibraries;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 tuyau "$out/bin/tuyau"
    install -Dm644 tuyau.desktop "$out/share/applications/tuyau.desktop"
    install -Dm644 tuyau.svg "$out/share/icons/hicolor/scalable/apps/tuyau.svg"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/tuyau" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries}
  '';

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://github.com/Vincent-HD/tuyau/releases/download/v${finalAttrs.version}/tuyau-${finalAttrs.version}-${artifact.arch}-linux.tar.gz";
        hash = artifact.hash;
      }
    ) artifacts;
    updateScript = packageUpdater.script {
      attr = "tuyau";
      file = ./default.nix;
      nixUpdateArgs = [ "--use-github-releases" ];
    };
  };

  meta = {
    description = "Declarative PipeWire patchbay with a graph editor and a CLI (prebuilt release binary)";
    homepage = "https://github.com/Vincent-HD/tuyau";
    changelog = "https://github.com/Vincent-HD/tuyau/releases/tag/v${finalAttrs.version}";
    mainProgram = "tuyau";
    platforms = builtins.attrNames artifacts;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
