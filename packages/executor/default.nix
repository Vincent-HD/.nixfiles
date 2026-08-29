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
      hash = "sha512-dub4ry1cgj4Emv8l9gudp5CPpcbKUC75gG6Fa6MhC4EBtesMEi3x++SKa4M9TbUG2AV1LG7RG1eDdcjMuQKNmQ==";
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
      hash = "sha512-oTlWJ4KxJ8yCGyHDRfEJo13IPwA6G0M1SAPDTeELMd4EeJVJWpGBwXEu8ZNebiMtjGQYnP99qqgaGPydj6mWEA==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.2";

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
