{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  cairo,
  dbus,
  fontconfig,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  bun,
  updateScriptZod,
}:
let
  # Tauri release artifacts from github.com/open-pencil/open-pencil.
  sources = {
    "x86_64-linux" = {
      asset = "OpenPencil_0.17.0_amd64.deb";
      hash = "sha256-fuxRsdxJUZWrTCp4N4TetZfQXI10zUZK860wa0TIXI0=";
    };
    "aarch64-darwin" = {
      asset = "OpenPencil_aarch64.app.tar.gz";
      hash = "sha256-qNkOVzNcBReOJsk55hb1EtijMKO0G/bqCBPbr898sxU=";
    };
    "x86_64-darwin" = {
      asset = "OpenPencil_x64.app.tar.gz";
      hash = "sha256-fFcKocIOZ/93vF0NRmnGUa0vLPUNHP7/wkmvIr4XvQk=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};

  # The deb registers these types without defining them; add globs so .fig and .pen resolve.
  mimeDefinitions = ./open-pencil-mime.xml;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "open-pencil";
  version = "0.17.0";

  src = fetchurl {
    url = "https://github.com/open-pencil/open-pencil/releases/download/v${finalAttrs.version}/${source.asset}";
    hash = source.hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    cairo
    dbus
    fontconfig
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libsoup_3
    webkitgtk_4_1
  ];

  sourceRoot = ".";
  unpackCmd = lib.optionalString stdenv.hostPlatform.isLinux ''
    dpkg-deb -x "$curSrc" .
  '';

  dontConfigure = true;
  dontBuild = true;
  # Keep the signed macOS bundle intact.
  dontFixup = stdenv.hostPlatform.isDarwin;

  installPhase =
    if stdenv.hostPlatform.isLinux then
      ''
        runHook preInstall
        mkdir -p "$out/bin"
        install -Dm755 usr/bin/OpenPencil "$out/bin/open-pencil"
        cp -R usr/share "$out/"
        install -Dm644 ${mimeDefinitions} "$out/share/mime/packages/open-pencil.xml"
        substituteInPlace "$out/share/applications/OpenPencil.desktop" \
          --replace-fail "Exec=OpenPencil " "Exec=$out/bin/open-pencil " \
          --replace-fail "Categories=" "Categories=Graphics;VectorGraphics;Development;"
        runHook postInstall
      ''
    else
      ''
        runHook preInstall
        mkdir -p "$out/Applications" "$out/bin"
        cp -R OpenPencil.app "$out/Applications/"
        ln -s "$out/Applications/OpenPencil.app/Contents/MacOS/OpenPencil" "$out/bin/open-pencil"
        runHook postInstall
      '';

  # WebKitGTK's DMA-BUF renderer shows a blank window on the NVIDIA proprietary driver.
  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(--set-default WEBKIT_DISABLE_DMABUF_RENDERER 1)
  '';

  passthru = {
    bundleIdentifier = "net.dannote.open-pencil";
    desktopFile = "OpenPencil.desktop";
    updateScript = [
      (lib.getExe bun)
      "${../..}/packages/open-pencil/update.ts"
      "${updateScriptZod}/index.js"
    ];
  };

  meta = {
    description = "AI-native open-source design editor that opens Figma and pen.dev files";
    homepage = "https://openpencil.dev";
    changelog = "https://github.com/open-pencil/open-pencil/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "open-pencil";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
