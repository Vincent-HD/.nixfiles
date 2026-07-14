{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sunshine-darwin";
  version = "2026.713.170739";

  src = fetchurl {
    url = "https://github.com/LizardByte/Sunshine/releases/download/v${finalAttrs.version}/Sunshine-macOS-arm64.dmg";
    hash = "sha256-bp+v0PmNJeMxpkOwMTWwxK4uWDVS+EPYJJqmHW9fGFA=";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R Sunshine.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Self-hosted game stream host for Moonlight";
    homepage = "https://app.lizardbyte.dev/Sunshine";
    license = lib.licenses.gpl3Only;
    platforms = [ "aarch64-darwin" ];
  };
})
