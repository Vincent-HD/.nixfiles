{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  qt6,
  libglvnd,
  pkgsi686Linux,
  bun,
  updateScriptZod,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "lsfg-vk";
  version = "2.0.0";
  # Upstream's archive contains both the x86_64 and i686 Vulkan layers.
  src = fetchurl {
    url = "https://builds.lsfg-vk.dev/lsfg-vk-${finalAttrs.version}.tar.xz";
    hash = "sha256-CL2983OhEQIt+H2seqh+O1ZLuEH5YVUuPKhf6hK1qnQ=";
  };
  sourceRoot = ".";
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    qt6.wrapQtAppsHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    qt6.qtbase
    qt6.qtdeclarative
    libglvnd
    pkgsi686Linux.stdenv.cc.cc.lib
    pkgsi686Linux.glibc
  ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bin lib share "$out/"
    # The automatic hook targets x86_64 only, so set the i686 library path separately.
    patchelf --set-rpath ${
      lib.escapeShellArg (
        lib.makeLibraryPath [
          pkgsi686Linux.stdenv.cc.cc.lib
          pkgsi686Linux.stdenv.cc.cc.libgcc
          pkgsi686Linux.glibc
        ]
      )
    } "$out/lib/liblsfg-vk-layer.x86.so"
    runHook postInstall
  '';
  passthru.updateScript = [
    (lib.getExe bun)
    "${../..}/packages/lsfg-vk/update.ts"
    "${updateScriptZod}/index.js"
  ];
  meta = {
    description = "Lossless Scaling frame generation Vulkan layer, CLI, and Qt interface";
    homepage = "https://lsfg-vk.dev/";
    changelog = "https://git.lsfg-vk.dev/lsfg-vk/tag/${finalAttrs.version}";
    license = lib.licenses.cc-by-nc-nd-40;
    mainProgram = "lsfg-vk-ui";
    platforms = [ "x86_64-linux" ];
  };
})
