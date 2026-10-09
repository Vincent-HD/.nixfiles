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
      hash = "sha256-gWi4arXZS+j2cJkt/k/hRFAWUYqGS0i9oQXmQULny/k=";
    };
    "x86_64-darwin" = {
      suffix = "darwin-x64";
      hash = "sha256-eHy0DghqGI0LsT/ympmgsjgK/zql6GALj4ExoLmMppw=";
    };
    "x86_64-linux" = {
      suffix = "linux-x64";
      hash = "sha256-pUt2UZLbd0Zm8FE/qLVFoph1O28p5zvN9KHnjxjnwOE=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "agent-browser";
  version = "0.38.2";

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
