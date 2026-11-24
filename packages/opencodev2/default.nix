{
  fetchurl,
  lib,
  stdenvNoCC,
  packageUpdater,
}:

let
  # OpenCode publishes one self-contained npm binary package per platform.
  artifacts = {
    "aarch64-darwin" = {
      package = "cli-darwin-arm64";
      hash = "sha512-r6PIZl5wqFxVYfVFjm2JK4uf1a3YT7FMEVTODJF/1hKe6wBdK7THzbAM1SSyuRuMnSkDb9+dd8xNOk9zQK6trg==";
    };
    "x86_64-linux" = {
      package = "cli-linux-x64";
      hash = "sha512-FYQAnneVlLmqy862674vvRVkj8yHuZAFHJGV3UCGQxo8aKG58IHPKrspbxruVajnIEpb0t8PeO63H/oW4vJG5A==";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencodev2";
  version = "2.4.1";

  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode "$out/bin/opencode"
    ln -s opencode "$out/bin/opencode2"

    runHook postInstall
  '';

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://registry.npmjs.org/@opencode/${artifact.package}/-/${artifact.package}-${finalAttrs.version}.tgz";
        hash = artifact.hash;
      }
    ) artifacts;
    # OpenCode's own update endpoint names the current V2 release.
    updateScript = packageUpdater.script {
      attr = "opencodev2";
      file = ./default.nix;
      latestVersion = "curl -fsS https://opencode.ai/update/api/latest/cli/npm | jq -r .version";
    };
  };

  meta = {
    description = "Open source AI coding agent V2";
    homepage = "https://opencode.ai/v2/";
    changelog = "https://github.com/anomalyco/opencode/releases";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = builtins.attrNames artifacts;
  };
})
