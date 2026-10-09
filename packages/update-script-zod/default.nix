{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "update-script-zod";
  version = "4.6.5";

  src = fetchurl {
    url = "https://registry.npmjs.org/zod/-/zod-${finalAttrs.version}.tgz";
    hash = "sha256-p4wMUz3jDcHEr8JZrEOsBuOQyw2o0uMurjVTAbULNvw=";
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
