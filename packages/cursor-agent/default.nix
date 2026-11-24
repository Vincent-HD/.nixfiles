{
  lib,
  fetchurl,
  stdenvNoCC,
  packageUpdater,
}:

let
  # Cursor's download path segments and archive hash for each supported platform.
  artifacts = {
    "x86_64-linux" = {
      platform = "linux";
      architecture = "x64";
      hash = "sha256-dmOxxdG1bgle+OI77zjWbfbP1mXEhzRwIU4OQR8Pl7M=";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha256-e33QAg+5oqnh5+Pzni+fUS0d2VdxdOzaiqgqwx28lWU=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha256-FsxzFBKCQ7JNdFdcrl9+GiFWVtSBFdVQhOLWcl73xUI=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha256-kvOeRIIYiXU4vYAc2wHWkQarN6hqrz3A5rVRWcebdeI=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor-agent";
  version = "2026.11.22-e9042b2";

  # Cursor publishes one self-contained Agent CLI archive per OS/architecture.
  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

  sourceRoot = "dist-package";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/cursor-agent"
    cp -a ./. "$out/lib/cursor-agent/"
    ln -s "$out/lib/cursor-agent/cursor-agent" "$out/bin/agent"
    ln -s "$out/lib/cursor-agent/cursor-agent" "$out/bin/cursor-agent"

    runHook postInstall
  '';

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://downloads.cursor.com/lab/${finalAttrs.version}/${artifact.platform}/${artifact.architecture}/agent-cli-package.tar.gz";
        hash = artifact.hash;
      }
    ) artifacts;
    # The official installer script embeds the current release path.
    updateScript = packageUpdater.script {
      attr = "cursor-agent";
      file = ./default.nix;
      latestVersion = "curl -fsS https://cursor.com/install | sed -nE 's|.*downloads\\.cursor\\.com/lab/([^/]+)/.*|\\1|p' | sed -n 1p";
    };
  };

  meta = {
    description = "Cursor's AI coding agent for the terminal";
    homepage = "https://cursor.com/docs/cli/overview";
    license = lib.licenses.unfree;
    mainProgram = "agent";
    platforms = builtins.attrNames artifacts;
  };
})
