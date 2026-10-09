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
      hash = "sha256-p5cmxuZEUg6ZOXC+TEV3WmiJgCtnq+RhpnelMhmuKOg=";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha256-eFxfa/KmDrESHiftjBT17gftG1tmkjJPLZqZcjgkXrU=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha256-qA224VYm4Kp69g+rOpXJiiQ+LBUTwMlIU0SlU9e3sA4=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha256-Yp5R3kOgt/s7hvXrx+V59999+UGznynoKUXN51AUWvw=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor-agent";
  version = "2026.10.01-e373342";

  # Cursor publishes one self-contained Agent CLI archive per OS/architecture.
  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${finalAttrs.version}/${source.platform}/${source.architecture}/agent-cli-package.tar.gz";
    hash = source.hash;
  };

  sourceRoot = "dist-package";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/cursor-agent"
    cp -a ./. "$out/lib/cursor-agent/"
    ln -s "$out/lib/cursor-agent/cursor-agent" "$out/bin/agent"
    ln -s "$out/lib/cursor-agent/cursor-agent" "$out/bin/cursor-agent"

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    "${../..}/packages/cursor-agent/update.ts"
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Cursor's AI coding agent for the terminal";
    homepage = "https://cursor.com/docs/cli/overview";
    license = lib.licenses.unfree;
    mainProgram = "agent";
    platforms = builtins.attrNames sources;
  };
})
