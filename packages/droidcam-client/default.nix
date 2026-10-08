{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  qt5,
  android-tools,
  alsa-lib,
  bzip2,
  curl,
  fontconfig,
  freetype,
  glib,
  jansson,
  libGL,
  libpulseaudio,
  libx11,
  libxcb,
  libxkbcommon,
  pciutils,
  speexdsp,
  wayland,
  xz,
  zlib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "droidcam-client";
  version = "7.2.1";

  src = fetchurl {
    url = "https://github.com/dev47apps/droidcam-obs-client/releases/download/droidcam-${finalAttrs.version}/droidcam_client_${finalAttrs.version}_amd64.deb";
    hash = "sha256-yzAn5k1lnbCWfjoJVfOBJA/loocE4rYDH+5F5cEUUWU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    qt5.wrapQtAppsHook
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    qt5.qtbase
    qt5.qtsvg
    qt5.qtwayland
    alsa-lib
    bzip2
    curl
    fontconfig
    freetype
    glib
    jansson
    libGL
    libpulseaudio
    libx11
    libxcb
    libxkbcommon
    pciutils
    speexdsp
    wayland
    xz
    zlib
  ];

  dontBuild = true;
  dontWrapQtApps = true;
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec" "$out/bin" "$out/share/applications"
    cp -a opt/droidcam-obs-client "$out/libexec/"
    install -Dm644 opt/droidcam-obs-client/icon.png "$out/share/icons/hicolor/256x256/apps/droidcam-client.png"
    substitute usr/share/applications/com.dev47apps.droidcam.desktop \
      "$out/share/applications/com.dev47apps.droidcam.desktop" \
      --replace-fail "Name=DroidCam Client (OBS)" "Name=DroidCam" \
      --replace-fail "Icon=/opt/droidcam-obs-client/icon.png" "Icon=droidcam-client" \
      --replace-fail "Path=/opt/droidcam-obs-client/bin/64bit" "Path=$out/libexec/droidcam-obs-client/bin/64bit" \
      --replace-fail "Exec=/usr/local/bin/droidcam" "Exec=$out/bin/droidcam-client"
    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath "$out/libexec/droidcam-obs-client/bin/64bit"
  '';
  postFixup = ''
    makeWrapper "$out/libexec/droidcam-obs-client/bin/64bit/droidcam" "$out/bin/droidcam-client" \
      --chdir "$out/libexec/droidcam-obs-client/bin/64bit" \
      --prefix PATH : "${lib.makeBinPath [ android-tools ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL ]}:$out/libexec/droidcam-obs-client/bin/64bit" \
      "''${qtWrapperArgs[@]}"
  '';

  meta = {
    description = "DroidCam desktop client with camera preview and controls";
    homepage = "https://www.droidcam.app/linux/";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "droidcam-client";
  };
})
