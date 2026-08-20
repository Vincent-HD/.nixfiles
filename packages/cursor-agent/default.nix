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
      hash = "sha256-v/9L9vTp3TDB0O8KcLYHewdAFd0pSOTFBoXVOv3Pzlo=";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha256-KYYVKyg8cKZmsBUDWy6ZqW0Tr9JmClh7hjlBfP3RR/s=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha256-5F7XyF4gCAMQd4/1onBQyWF5iNxeda0/rwCvgeT34BE=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha256-RgRNbXvL17SaDPHNAapMp5qqLqXyx6MpZfwOvimEF5A=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor-agent";
  version = "2026.08.11-e8db854";

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
    ./update.ts
  ];

  meta = {
    description = "Cursor's AI coding agent for the terminal";
    homepage = "https://cursor.com/docs/cli/overview";
    license = lib.licenses.unfree;
    mainProgram = "agent";
    platforms = builtins.attrNames sources;
  };
})
