{
  lib,
  stdenvNoCC,
  bun,
  fetchurl,
  updateScriptZod,
}:

let
  sources = {
    "aarch64-darwin" = {
      artifact = "ryu-darwin-arm64.tar.gz";
      hash = "sha256-hl45qwUp3F258b+fvCryaW2L3LrFC8NC1a4tZMzSpVc=";
    };
    "x86_64-linux" = {
      artifact = "ryu-linux-x64.tar.gz";
      hash = "sha256-fM3DQZYW5pJ6EaR1u1u0J4Sx44u0EUKW3JLU29xi/us=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jj-ryu";
  version = "0.0.1-alpha.12";

  src = fetchurl {
    url = "https://github.com/dmmulroy/jj-ryu/releases/download/v${finalAttrs.version}/${source.artifact}";
    hash = source.hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 ryu "$out/bin/ryu"
    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    ./update.ts
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Stacked PRs for Jujutsu with GitHub/GitLab support";
    homepage = "https://github.com/dmmulroy/jj-ryu";
    license = lib.licenses.mit;
    mainProgram = "ryu";
    platforms = builtins.attrNames sources;
  };
})
