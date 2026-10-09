{
  lib,
  bun,
  fetchurl,
  stdenvNoCC,
  updateScriptZod,
}:

let
  sources = {
    "x86_64-linux" = {
      platform = "linux";
      architecture = "x64";
      hash = "sha512-njvy/LzUWlVdDXuKTTGX6NCKhDpKdRjMf2T7KqumaZd2A7ZqXoIl65qeAyklFU+kkalLS6QW1Xs3lSSj+nfAPw==";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha512-SyzZsunGUhgwZoFEiWVqEIPV3h25SHKToWLrwId3p7FJqGuP/9ixMeOeXZ1CIS9j2kCws3F5iSUi3DQQ/6uxdw==";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha512-KA7sGlSV/3uXL5ZOv8YJd1HBoYR3DPDxQlVcsxzF+jdLjvDTKrl+n2eQ3imzlYMwps80AqDHk+rcFg8zEJXI7w==";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha512-rPuEL8ibW7k6jkAa714wAiiw3YGWtQ4btMmCSDdLGzEIBj2FoBNjOu76okIF10H3fYbrituss0VeX5KEPFbv/w==";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.10";

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
    "${../..}/packages/executor/update.ts"
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Local integration layer and MCP proxy for AI agents";
    homepage = "https://executor.sh";
    license = lib.licenses.mit;
    mainProgram = "executor";
    platforms = builtins.attrNames sources;
  };
})
