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
      hash = "sha256-b2vzndLfKdzThkPN+rAVXOcWmZU4ifcy3uwSP2Viuy0=";
    };
    "aarch64-linux" = {
      platform = "linux";
      architecture = "arm64";
      hash = "sha256-y7pA2Q1/aZh04TOlwVvzhUzuAGVlvTuwCmx5tJ1isNA=";
    };
    "x86_64-darwin" = {
      platform = "darwin";
      architecture = "x64";
      hash = "sha256-EPvV0hOrft/HN33QDTLoVtipnC7ELDtNJlM4yeUz9yM=";
    };
    "aarch64-darwin" = {
      platform = "darwin";
      architecture = "arm64";
      hash = "sha256-xtni6qGx4kIhUX4LQgax8Vk3kubw2KUum1B7vnqwzHc=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor-agent";
  version = "2026.10.14-941492e";

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
