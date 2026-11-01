{
  bun,
  fetchurl,
  lib,
  stdenvNoCC,
  updateScriptZod,
}:

let
  sources = {
    "aarch64-darwin" = {
      suffix = "darwin-arm64";
      hash = "sha256-pAL+8kicIhsXUiqiHxA8pdxH8A/1h51KcsOYgVRHMKs=";
    };
    "x86_64-darwin" = {
      suffix = "darwin-x64";
      hash = "sha256-8QjUqgL0Hu4F1rGwWBdHX9XVdtgCgmeD74CADaFvM+I=";
    };
    "x86_64-linux" = {
      suffix = "linux-x64";
      hash = "sha256-OZx+nwa9KaqTP98lwL2VjuoGkn/Azm9Ta6Y0eqvWRig=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "agent-browser";
  version = "0.41.0";

  src = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/releases/download/v${finalAttrs.version}/agent-browser-${source.suffix}";
    hash = source.hash;
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/agent-browser"
    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    "${../..}/packages/agent-browser/update.ts"
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Fast native browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "agent-browser";
    platforms = builtins.attrNames sources;
  };
})
