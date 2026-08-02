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
      hash = "sha512-15iI8jTfSVLvQlS2225masTuT5A4sr6/Vd2bBVslHMCHeiWxhbaX4v7FMw9CDCG56xcGyFsMyIDfesxic4/5Wg==";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha512-xZcoyHtxLwTYtTAXj2kkhj0Gj38dSOvIKynfRM7Ewe/NzpW/dxvRNO6qoEcdMHIsYew86EcBbD13WRC3zckASg==";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha512-fIOchRZGqvbu/d9VJwQYMrQg/s/l6Rs2oBhHl4s1gIrzz84VweYvml//jPJ/uH7hhT/9gnQzVkWgSzNh4sQJQg==";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha512-fmlBxScveCgU0pCRNZuseTlXAKAkAHLjVcisB4SIrkMVMSIPbFJ9SQOwJXT4pEOL8ED4GJ9Fz4lNdTZwa5A9+g==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.5.37";

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
