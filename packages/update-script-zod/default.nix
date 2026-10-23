{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "update-script-zod";
  version = "4.6.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/zod/-/zod-${finalAttrs.version}.tgz";
    hash = "sha256-hO/RVb7ZMnAobnk/yVG+JwtTbL1bDusRHw+jlnIB1pg=";
  };

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Zod runtime schema library for package update scripts";
    homepage = "https://zod.dev";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
