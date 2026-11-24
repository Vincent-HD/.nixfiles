{
  lib,
  fetchurl,
  stdenvNoCC,
  packageUpdater,
}:

let
  # npm version suffix and tarball integrity for each supported platform.
  artifacts = {
    "x86_64-linux" = {
      platform = "linux";
      architecture = "x64";
      hash = "sha512-GzSkw26qGL9Tyk1FfeRctEY9743e91OVhtL+czmnAEaNYS2O3cjFJPZrTDWTjl30kxnAVkjxX8zoVH7PV3T2Wg==";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha512-wuGN0QuCmUOwntG0jayHaNMWsP1n1XzB9e0TryZEYCbYqfWJXwNulqi4mb93UW+Ej3uKphLpifaVUWB5bllHrg==";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha512-5gH+6Uq8b7T4nEFsYQRXGr8PvIgImPGsSiO/ThgPme8pEEGz9A7ERKD8NGKKPBjLwCt0z0JA9HROXvX0GRJeMA==";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha512-G2AABJVhsGiyqw1dAD700urT1RJ0MFg09dpVQSn20Nrue5ev91Cd0V32+4cTLufqRF9MNluPMEddhIEPhQoeMQ==";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.11";

  # Executor publishes one self-contained Bun binary for each OS/architecture.
  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a bin "$out/"

    runHook postInstall
  '';

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://registry.npmjs.org/executor/-/executor-${finalAttrs.version}-${artifact.platform}-${artifact.architecture}.tgz";
        hash = artifact.hash;
      }
    ) artifacts;
    # Platform builds are published as suffixed npm versions; `latest` names the release.
    updateScript = packageUpdater.script {
      attr = "executor";
      file = ./default.nix;
      latestVersion = "curl -fsS https://registry.npmjs.org/executor/latest | jq -r .version";
    };
  };

  meta = {
    description = "Local integration layer and MCP proxy for AI agents";
    homepage = "https://executor.sh";
    license = lib.licenses.mit;
    mainProgram = "executor";
    platforms = builtins.attrNames artifacts;
  };
})
