{
  lib,
  bun,
  fetchurl,
  stdenvNoCC,
}:

let
  sources = {
    "x86_64-linux" = {
      platform = "linux";
      architecture = "x64";
      hash = "sha512-u1cLLOLzoKOQu+kpAta/U8ztycLjpCCOJW67I95BRLzbcf02F2M5pe9y5U3A2luWA46G9WOQGGQ6EfX1F/RP8Q==";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha512-Opu3QmuUB4kYlcdSUHEy89h9FWNpN+GcOcpoz+T1ehfI1I+MHDlnepn3cjxFX3SVDO8zcWrYnDesmbTlZLYT0w==";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha512-7BEftSu2BCseSgTBjCAnZt2ePj4l6j7P3FOgvVfJkHkPaXN1grx65pmRiQudEEHyR7ZbewEM0pZUEa/szVmABA==";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha512-28fwaFwDyHrpVG39hhN0uGdWOJgCr0C7EM8P11CUT3ifM4Kg2H2kSCk7VOMk6F7oDtaBdfOObvZkJOadC0CJtw==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.8";

  # Executor publishes one self-contained Bun binary for each OS/architecture.
  src = fetchurl {
    url = "https://registry.npmjs.org/executor/-/executor-${finalAttrs.version}-${source.platform}-${source.architecture}.tgz";
    hash = source.hash;
  };

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a bin "$out/"

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    ./update.ts
  ];

  meta = {
    description = "Local integration layer and MCP proxy for AI agents";
    homepage = "https://executor.sh";
    license = lib.licenses.mit;
    mainProgram = "executor";
    platforms = builtins.attrNames sources;
  };
})
