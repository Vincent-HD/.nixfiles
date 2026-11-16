{
  appName,
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  _7zz,
  alsa-lib,
  dbus,
  fontconfig,
  libglvnd,
  libva,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrender,
  vulkan-loader,
  wayland,
  bun,
  updateScriptZod,
}:
let
  # One pin file for every ArtCraft app; each app is its own GitHub repository
  # (github.com/storytold/<app>) with identically named release artifacts.
  pins = (lib.importJSON ./sources.json).${appName};

  # Map Nix systems to the upstream artifact suffix; macOS ships one universal DMG.
  artifacts = {
    "x86_64-linux" = "linux-x86_64.tar.gz";
    "aarch64-darwin" = "macos-universal.dmg";
    "x86_64-darwin" = "macos-universal.dmg";
  };
  artifact = artifacts.${stdenv.hostPlatform.system};

  # Libraries the winit/wgpu GUI dlopens at runtime instead of linking.
  runtimeLibraries = [
    dbus
    fontconfig
    libglvnd
    libva
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    libxrender
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = appName;
  version = pins.version;

  src = fetchurl {
    url = "https://github.com/storytold/${appName}/releases/download/v${finalAttrs.version}/${appName}-${finalAttrs.version}-${artifact}";
    hash = pins.hashes.${artifact};
  };

  nativeBuildInputs =
    if stdenv.hostPlatform.isLinux then
      [
        autoPatchelfHook
        makeWrapper
      ]
    else
      [ _7zz ];

  # FilmCraft links ALSA directly; the rest only need the C++ runtime.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    alsa-lib
  ];

  sourceRoot = if stdenv.hostPlatform.isLinux then "${appName}-${finalAttrs.version}-linux-x86_64" else ".";

  # The HFS+ DMG uses a block layout undmg cannot read, so unpack it with 7-Zip.
  unpackCmd = lib.optionalString stdenv.hostPlatform.isDarwin ''
    7zz x -snld "$curSrc"
  '';

  dontConfigure = true;
  dontBuild = true;
  # Keep the signed macOS bundle byte-for-byte intact.
  dontFixup = stdenv.hostPlatform.isDarwin;

  installPhase =
    if stdenv.hostPlatform.isLinux then
      ''
        runHook preInstall
        mkdir -p "$out"
        cp -R bin share "$out/"
        substituteInPlace "$out/share/applications/ai.storyteller.${appName}.desktop" \
          --replace-fail "Exec=${appName} " "Exec=$out/bin/${appName} " \
          --replace-fail "TryExec=${appName}" "TryExec=$out/bin/${appName}"
        runHook postInstall
      ''
    else
      ''
        runHook preInstall
        mkdir -p "$out/Applications" "$out/bin"
        cp -R "${pins.displayName}/${pins.displayName}.app" "$out/Applications/"
        ln -s "$out/Applications/${pins.displayName}.app/Contents/MacOS/${pins.displayName}" "$out/bin/${appName}"
        ln -s "$out/Applications/${pins.displayName}.app/Contents/MacOS/${appName}-cli" "$out/bin/${appName}-cli"
        runHook postInstall
      '';

  # NVIDIA decode/encode libraries come from the host driver, not the Nix closure.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/${appName}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}" \
      --suffix LD_LIBRARY_PATH : /run/opengl-driver/lib
  '';

  passthru = {
    displayName = pins.displayName;
    bundleIdentifier = "ai.storyteller.${appName}";
    desktopFile = "ai.storyteller.${appName}.desktop";
    updateScript = [
      (lib.getExe bun)
      "${../..}/packages/craft-apps/update.ts"
      "${updateScriptZod}/index.js"
      appName
    ];
  };

  meta = {
    description = pins.description;
    homepage = "https://github.com/storytold/${appName}";
    changelog = "https://github.com/storytold/${appName}/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = appName;
    platforms = builtins.attrNames artifacts;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
