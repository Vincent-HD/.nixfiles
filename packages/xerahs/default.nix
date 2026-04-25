{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  icu,
  openssl,
  libx11,
  libice,
  libsm,
  libGL,
  gcc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "xerahs";
  version = "0.21.2";

  src = fetchurl {
    url = "https://github.com/ShareX/XerahS/releases/download/v${finalAttrs.version}/XerahS-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-UXunG1nk1SJB0ygMqbTL7W3EtjZpP0Pqx+ShPIBfhbI=";
  };

  # Icon from develop branch for a stable URL that doesn't need updating
  # when the version changes.
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/ShareX/XerahS/develop/src/desktop/app/XerahS.UI/Assets/Logo.png";
    hash = "sha256-E/2/6mrNOiMKzNAX7G1GXzQvu42A8iIcOodIcDVLuhY=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontStrip = true;
  dontPatchELF = true;

  sourceRoot = ".";

  installPhase = ''
        runHook preInstall

        mkdir -p $out/lib/xerahs
        cp -rT . $out/lib/xerahs

        chmod 755 $out/lib/xerahs/XerahS
        if [ -f $out/lib/xerahs/xerahs-watchfolder-daemon ]; then
          chmod 755 $out/lib/xerahs/xerahs-watchfolder-daemon
        fi

        mkdir -p $out/bin
        makeWrapper $out/lib/xerahs/XerahS $out/bin/xerahs \
          --prefix LD_LIBRARY_PATH : "${
            lib.makeLibraryPath [
              icu
              openssl
              libx11
              libice
              libsm
              libGL
              gcc.cc.lib
            ]
          }"

        mkdir -p $out/share/icons/hicolor/256x256/apps
        cp ${finalAttrs.icon} $out/share/icons/hicolor/256x256/apps/com.getsharex.XerahS.png

        mkdir -p $out/share/applications
        cat > $out/share/applications/com.getsharex.XerahS.desktop <<'EOF'
    [Desktop Entry]
    Name=XerahS
    Comment=Cross-platform screen capture and sharing tool
    GenericName=Screen Capture
    Exec=xerahs %U
    Icon=com.getsharex.XerahS
    Terminal=false
    Type=Application
    Categories=Utility;Graphics;
    Keywords=screenshot;screen;capture;share;upload;
    StartupWMClass=xerahs
    X-GNOME-UsesNotifications=true
    EOF

        runHook postInstall
  '';

  meta = {
    description = "Cross-platform screen capture and sharing tool";
    homepage = "https://github.com/ShareX/XerahS";
    license = lib.licenses.gpl3;
    mainProgram = "xerahs";
    platforms = [ "x86_64-linux" ];
  };
})
