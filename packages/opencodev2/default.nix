{
  bun,
  fetchurl,
  lib,
  stdenvNoCC,
  updateScriptZod,
}:

let
  # OpenCode publishes one self-contained npm binary package per platform.
  sources = {
    "aarch64-darwin" = {
      package = "cli-darwin-arm64";
      hash = "sha512-QwjyvovTdT0gFi5rxUyPVlYePIe3ELduR9olu+KJWe089XVIDOTMhxylBe/ZGIpvoXHYo6bp2NskIiqCFAEXsw==";
    };
    "x86_64-linux" = {
      package = "cli-linux-x64";
      hash = "sha512-o8EJ0ZsT4dzDKN+0mpG2EKbNGzJyp+F1++Av28UReRVfiEv+N34eZEnN/unkiMoerKHad6W6Ii7k4ukTnPNmNQ==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencodev2";
  version = "2.1.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/${source.package}/-/${source.package}-${finalAttrs.version}.tgz";
    hash = source.hash;
  };

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode "$out/bin/opencode"
    ln -s opencode "$out/bin/opencode2"

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    "${../..}/packages/opencodev2/update.ts"
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Open source AI coding agent V2";
    homepage = "https://opencode.ai/v2/";
    changelog = "https://github.com/anomalyco/opencode/releases";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = builtins.attrNames sources;
  };
})
