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
      hash = "sha512-EwunTL9Q/6GT+vnA5e9NJyLdFFHpj77bQI1JdyNNtSI7dKO/DHW2RlvKMty2uvONCTfA4zdkwop9GalLw5becg==";
    };
    "x86_64-linux" = {
      package = "cli-linux-x64";
      hash = "sha512-WVO7TebdgAcPnoOQ390ny3oyqpCH5MpPU76lHXml3G/wJz6QLxjzsQW2Lrabiewg046yAeKlf+1nPPZElF1qPw==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencodev2";
  version = "2.1.3";

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
