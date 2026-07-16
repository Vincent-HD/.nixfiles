{
  bun,
  coreutils,
  dxvk,
  fetchurl,
  findutils,
  gobject-introspection,
  gtk3,
  lib,
  libnotify,
  makeWrapper,
  p7zip,
  python3,
  stdenvNoCC,
  webkitgtk_4_1,
  wineWow64Packages,
  winetricks,
  wrapGAppsHook3,
  xdg-utils,
}:

let
  # Fusion creates captionless utility windows that Wine otherwise promotes to
  # separate managed windows. Build the small upstream fix into nixpkgs Wine.
  fusionWine = wineWow64Packages.stagingFull.overrideAttrs (oldAttrs: {
    pname = "${oldAttrs.pname}-fusion360";
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--disable-tests" ];
    patches = (oldAttrs.patches or [ ]) ++ [ ./wine-captionless-popups.patch ];
  });

  # Keep Autodesk's OAuth flow in one WebKitGTK window so Wine never has to
  # round-trip the adskidmgr callback through an external browser.
  fusionLogin = stdenvNoCC.mkDerivation {
    pname = "fusion360-login";
    version = "0.1.0";

    dontUnpack = true;
    dontWrapGApps = true;

    nativeBuildInputs = [
      gobject-introspection
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = [
      gtk3
      webkitgtk_4_1
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/share/fusion360"
      cp ${./fusion360-login.py} "$out/share/fusion360/fusion360-login.py"

      runHook postInstall
    '';

    preFixup = ''
      makeWrapper '${python3.withPackages (pythonPackages: [ pythonPackages.pygobject3 ])}/bin/python' \
        "$out/bin/fusion360-login" \
        --add-flags "$out/share/fusion360/fusion360-login.py" \
        --prefix PATH : '${lib.makeBinPath [ libnotify xdg-utils ]}' \
        "''${gappsWrapperArgs[@]}"
    '';

    meta.mainProgram = "fusion360-login";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fusion360";
  version = "2704.1.23";

  # Autodesk replaces this URL in place. The fixed hash keeps the complete
  # offline installer reproducible until the package is intentionally updated.
  adminInstaller = fetchurl {
    url = "https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe";
    name = "fusion360-admin-installer.exe";
    hash = "sha256-8YvUmfLquq0FLzk2U9mNaudM9lH+0KOkPUOGTxxHWt8=";
  };

  # WebView2 109 is the Wine-tested release used by the upstream Linux recipe.
  webView2Installer = fetchurl {
    url = "https://github.com/aedancullen/webview2-evergreen-standalone-installer-archive/releases/download/109.0.1518.78/MicrosoftEdgeWebView2RuntimeInstallerX64.exe";
    hash = "sha256-8sxJhj4iFALUZk2fqUSkfyJUPaLcs2NDjD5Zh4m5/Vs=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/fusion360"
    cp ${./NMachineSpecificOptions.xml} "$out/share/fusion360/NMachineSpecificOptions.xml"
    cp ${./fusion360.sh} "$out/share/fusion360/fusion360.sh"

    substituteInPlace "$out/share/fusion360/fusion360.sh" \
      --replace-fail '@adminInstaller@' "$adminInstaller" \
      --replace-fail '@dxvk@' '${dxvk.bin}' \
      --replace-fail '@find@' '${lib.getExe' findutils "find"}' \
      --replace-fail '@loginHelper@' '${lib.getExe fusionLogin}' \
      --replace-fail '@options@' "$out/share/fusion360/NMachineSpecificOptions.xml" \
      --replace-fail '@version@' '${finalAttrs.version}' \
      --replace-fail '@webView2Installer@' "$webView2Installer" \
      --replace-fail '@wine@' '${lib.getExe fusionWine}' \
      --replace-fail '@wineboot@' '${lib.getExe' fusionWine "wineboot"}' \
      --replace-fail '@winecfg@' '${lib.getExe' fusionWine "winecfg"}' \
      --replace-fail '@wineserver@' '${lib.getExe' fusionWine "wineserver"}' \
      --replace-fail '@winetricks@' '${lib.getExe winetricks}' \
      --replace-fail '@winetricksWine@' '${fusionWine}/bin/.wine'

    patchShebangs "$out/share/fusion360/fusion360.sh"
    chmod +x "$out/share/fusion360/fusion360.sh"
    for command in fusion360 fusion360-diagnose fusion360-setup fusion360-uri-handler fusion360-winecfg; do
      makeWrapper "$out/share/fusion360/fusion360.sh" "$out/bin/$command" \
        --set FUSION360_COMMAND "$command" \
        --prefix PATH : '${
          lib.makeBinPath [
            coreutils
            findutils
            fusionWine
          ]
        }'
    done

    runHook postInstall
  '';

  passthru = {
    wine = fusionWine;
    updateScript = [
      (lib.getExe bun)
      ./update.ts
      (lib.getExe' p7zip "7z")
    ];
  };

  meta = {
    description = "Nix-managed Wine runtime and bootstrapper for Autodesk Fusion";
    homepage = "https://www.autodesk.com/products/fusion-360/overview";
    license = lib.licenses.unfree;
    mainProgram = "fusion360";
    platforms = [ "x86_64-linux" ];
  };
})
