{
  lib,
  stdenvNoCC,
  fetchurl,
  packageUpdater,
}:

let
  # Release archive name and hash for each supported platform.
  artifacts = {
    "aarch64-darwin" = {
      name = "ryu-darwin-arm64.tar.gz";
      hash = "sha256-hl45qwUp3F258b+fvCryaW2L3LrFC8NC1a4tZMzSpVc=";
    };
    "x86_64-linux" = {
      name = "ryu-linux-x64.tar.gz";
      hash = "sha256-fM3DQZYW5pJ6EaR1u1u0J4Sx44u0EUKW3JLU29xi/us=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jj-ryu";
  version = "0.0.1-alpha.12";

  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 ryu "$out/bin/ryu"
    runHook postInstall
  '';

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://github.com/dmmulroy/jj-ryu/releases/download/v${finalAttrs.version}/${artifact.name}";
        hash = artifact.hash;
      }
    ) artifacts;
    # Upstream only publishes alpha prereleases.
    updateScript = packageUpdater.script {
      attr = "jj-ryu";
      file = ./default.nix;
      nixUpdateArgs = [
        "--use-github-releases"
        "--version=unstable"
      ];
    };
  };

  meta = {
    description = "Stacked PRs for Jujutsu with GitHub/GitLab support";
    homepage = "https://github.com/dmmulroy/jj-ryu";
    license = lib.licenses.mit;
    mainProgram = "ryu";
    platforms = builtins.attrNames artifacts;
  };
})
