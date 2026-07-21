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
      hash = "sha256-G9iyPPVXvKljWPhkznRM0HGV3Evr2lNOG/qi7sSP98M=";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha256-gnmXeF8NjOk6WvfDstTosGS6hUP6z87vmBxurU0njYw=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha256-bf361rzCPLuq1KBv5C122vE7T8qTQ/JtayrdpFmf3/k=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha256-ISP5Nre+duoMEvfrsFfK6460buRBi3GFdiT/4S5eBUY=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor-agent";
  version = "2026.07.17-3e2a980";

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
