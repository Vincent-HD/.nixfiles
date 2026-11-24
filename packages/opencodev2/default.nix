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
      hash = "sha512-r6PIZl5wqFxVYfVFjm2JK4uf1a3YT7FMEVTODJF/1hKe6wBdK7THzbAM1SSyuRuMnSkDb9+dd8xNOk9zQK6trg==";
    };
    "x86_64-linux" = {
      package = "cli-linux-x64";
      hash = "sha512-FYQAnneVlLmqy862674vvRVkj8yHuZAFHJGV3UCGQxo8aKG58IHPKrspbxruVajnIEpb0t8PeO63H/oW4vJG5A==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencodev2";
  version = "2.4.1";

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
