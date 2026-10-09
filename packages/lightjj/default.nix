{
  lib,
  stdenvNoCC,
  bun,
  fetchurl,
  makeWrapper,
  jujutsu,
  git,
  gh,
  xdg-utils,
  openssh,
  updateScriptZod,
}:

let
  sources = {
    "aarch64-darwin" = {
      artifact = "lightjj-macos-arm64";
      hash = "sha256-NeQFDeI9gC2YCNt3pRtdeFJZHabae4VQ5ATweogAAb4=";
    };
    "x86_64-linux" = {
      artifact = "lightjj-linux-x86_64";
      hash = "sha256-8kf07nJRDNHagkO2f0ktDXh7GAiFQbICPqRMvWsSWz4=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lightjj";
  version = "1.38.0";

  src = fetchurl {
    url = "https://github.com/chronologos/lightjj/releases/download/v${finalAttrs.version}/${source.artifact}";
    hash = source.hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/lightjj"
    wrapProgram "$out/bin/lightjj" \
      --prefix PATH : ${
        lib.makeBinPath [
          jujutsu
          git
          gh
          xdg-utils
          openssh
        ]
      }
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    ./update.ts
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Fast browser UI for Jujutsu version control";
    homepage = "https://github.com/chronologos/lightjj";
    license = lib.licenses.mit;
    mainProgram = "lightjj";
    platforms = builtins.attrNames sources;
  };
})
