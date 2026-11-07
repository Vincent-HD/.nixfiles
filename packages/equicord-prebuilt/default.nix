{
  asar,
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "equicord-prebuilt";
  version = "2026-11-06";

  src = fetchurl {
    url = "https://github.com/Equicord/Equicord/releases/download/${finalAttrs.version}/equibop.asar";
    hash = "sha256-XV+EH3FGKxJZdGV3253CAVs1f+g69x/iqu4VMlCRh/g=";
  };

  nativeBuildInputs = [ asar ];
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    asar extract "$src" "$out/equibop"
    runHook postInstall
  '';

  meta = {
    description = "Official prebuilt Equicord for Equibop";
    homepage = "https://github.com/Equicord/Equicord";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
})
