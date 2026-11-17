{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  makeWrapper,
  unzip,
  libglvnd,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
  bun,
  updateScriptZod,
}:
let
  # Release artifacts from github.com/ibisjp/ibis-office; the macOS zip is Apple Silicon only.
  sources = {
    "x86_64-linux" = {
      asset = "Linux.AppImage";
      hash = "sha256-DGsV2TsoXNh/7Od26mvg152CbIiI8oZNx/AgMzMAhd0=";
    };
    "aarch64-darwin" = {
      asset = "macOS.zip";
      hash = "sha256-fwD/fcO8Y9BkeJ8vUblBaPftcvRgZm5gdGNBtBVyySA=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};

  # The single Rust binary dlopens its Wayland/X11 windowing and Vulkan/EGL rendering stacks.
  runtimeLibraries = [
    libglvnd
    libxcb
    libxkbcommon
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ibis-office";
  version = "0.8.7";

  src = fetchurl {
    url = "https://github.com/ibisjp/ibis-office/releases/download/v${finalAttrs.version}/ibisOffice-${finalAttrs.version}-${source.asset}";
    hash = source.hash;
  };

  # The AppImage is unpacked through appimageTools so no FHS runtime is needed.
  dontUnpack = stdenv.hostPlatform.isLinux;
  sourceRoot = ".";

  nativeBuildInputs =
    if stdenv.hostPlatform.isLinux then
      [
        autoPatchelfHook
        makeWrapper
      ]
    else
      [ unzip ];

  # libxcb and libxkbcommon are linked directly; the rest are dlopened.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    libxcb
    libxkbcommon
  ];

  dontConfigure = true;
  dontBuild = true;
  # Keep the signed macOS bundle byte-for-byte intact.
  dontFixup = stdenv.hostPlatform.isDarwin;

  installPhase =
    if stdenv.hostPlatform.isLinux then
      ''
        runHook preInstall
        mkdir -p "$out/bin"
        cp -R ${finalAttrs.passthru.appimageContents}/usr/share "$out/"
        chmod -R u+w "$out/share"
        install -Dm755 ${finalAttrs.passthru.appimageContents}/usr/bin/ibisOffice "$out/bin/ibisOffice"
        substituteInPlace "$out/share/applications/ibisoffice.desktop" \
          --replace-fail "Exec=ibisOffice " "Exec=$out/bin/ibisOffice "
        runHook postInstall
      ''
    else
      ''
        runHook preInstall
        mkdir -p "$out/Applications" "$out/bin"
        cp -R ibisOffice.app "$out/Applications/"
        ln -s "$out/Applications/ibisOffice.app/Contents/MacOS/ibisOffice" "$out/bin/ibisOffice"
        runHook postInstall
      '';

  # The GPU driver's Vulkan/EGL implementations come from the host, not the Nix closure.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/ibisOffice" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}" \
      --suffix LD_LIBRARY_PATH : /run/opengl-driver/lib
  '';

  passthru = {
    appimageContents = appimageTools.extract {
      pname = finalAttrs.pname;
      version = finalAttrs.version;
      src = finalAttrs.src;
    };
    bundleIdentifier = "jp.ne.ibis.office";
    desktopFile = "ibisoffice.desktop";
    updateScript = [
      (lib.getExe bun)
      "${../..}/packages/ibis-office/update.ts"
      "${updateScriptZod}/index.js"
    ];
  };

  meta = {
    description = "Fast GPU-rendered office suite for Word, Excel and PowerPoint files";
    homepage = "https://github.com/ibisjp/ibis-office";
    changelog = "https://github.com/ibisjp/ibis-office/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "ibisOffice";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
