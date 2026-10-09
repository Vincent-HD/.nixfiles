{
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "update-script-zod";
  version = "4.1.12";

  src = fetchurl {
    url = "https://registry.npmjs.org/zod/-/zod-${finalAttrs.version}.tgz";
    hash = "sha256-LvnXp9gisFnJvSH4fKpP3EgiDUNzU2eJhN+UL7Z7Q/o=";
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
