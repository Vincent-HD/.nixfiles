{
  fetchurl,
  lib,
  stdenvNoCC,
  packageUpdater,
}:

let
  # Release binary suffix and hash for each supported platform.
  artifacts = {
    "aarch64-darwin" = {
      suffix = "darwin-arm64";
      hash = "sha256-t2Lmv7b1xUX150mv36I8eAzOWGvf+NT8+OYfnavh2cY=";
    };
    "x86_64-darwin" = {
      suffix = "darwin-x64";
      hash = "sha256-0vn4HQ6gbQWNnBq4rLkwJ02tlwHQQIS2q+Kt4GYnhG0=";
    };
    "x86_64-linux" = {
      suffix = "linux-x64";
      hash = "sha256-03xyLXQkBV1/NSxL41qUJJ49xxKQZRbYLyZQ/OZ4nFQ=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "agent-browser";
  version = "0.44.0";

  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/agent-browser"
    runHook postInstall
  '';

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://github.com/vercel-labs/agent-browser/releases/download/v${finalAttrs.version}/agent-browser-${artifact.suffix}";
        hash = artifact.hash;
      }
    ) artifacts;
    updateScript = packageUpdater.script {
      attr = "agent-browser";
      file = ./default.nix;
      nixUpdateArgs = [ "--use-github-releases" ];
    };
  };

  meta = {
    description = "Fast native browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "agent-browser";
    platforms = builtins.attrNames artifacts;
  };
})
