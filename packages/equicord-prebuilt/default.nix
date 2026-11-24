{
  asar,
  fetchurl,
  lib,
  stdenvNoCC,
  packageUpdater,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "equicord-prebuilt";
  version = "2026-11-24";

  src = fetchurl {
    url = "https://github.com/Equicord/Equicord/releases/download/${finalAttrs.version}/equibop.asar";
    hash = "sha256-Up40cpBhhinXLVxs/comjMlywiVPKru3EYh+HH6LSEw=";
  };

  nativeBuildInputs = [ asar ];
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    asar extract "$src" "$out/equibop"
    runHook postInstall
  '';

  # Equicord tags releases by date.
  passthru.updateScript = packageUpdater.script {
    attr = "equicord-prebuilt";
    file = ./default.nix;
    nixUpdateArgs = [
      "--use-github-releases"
      "--version-regex=^(\\d{4}-\\d{2}-\\d{2})$"
    ];
  };

  meta = {
    description = "Official prebuilt Equicord for Equibop";
    homepage = "https://github.com/Equicord/Equicord";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
})
