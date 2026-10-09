{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  makeWrapper,
  bun,
  git,
  xdg-utils,
  updateScriptZod,
}:

let
  sources = {
    "x86_64-linux" = {
      artifact = "plannotator-linux-x64";
      hash = "sha256-7uLtpL84VEbjP5VOetY0G7yZ58ZxdnsQE4L1iza6vbE=";
    };
    "aarch64-linux" = {
      artifact = "plannotator-linux-arm64";
      hash = "sha256-Emgr2IeZqBQ2FR3umHsrek6PN/2C9HWaHfOd6UGuHeU=";
    };
    "x86_64-darwin" = {
      artifact = "plannotator-darwin-x64";
      hash = "sha256-Ycgt+Adgt6Tbjndb5sYIFzuvjSfrixSolJRBSairYhc=";
    };
    "aarch64-darwin" = {
      artifact = "plannotator-darwin-arm64";
      hash = "sha256-YS4jHMrBx1+in5/Zbg89aB3PDbOAQukpWAjtcrHTMog=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator";
  version = "0.28.8";

  src = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/${source.artifact}";
    hash = source.hash;
  };

  # Keep the upstream shared Agent Skills aligned with the packaged binary.
  coreSkillsSource = fetchFromGitHub {
    owner = "backnotprop";
    repo = "plannotator";
    rev = "v${finalAttrs.version}";
    hash = "sha256-/S7lPfKzY4c4lYyiEVuHuigqejoVVtbDzjon2VLvfo0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/plannotator"
    mkdir -p "$out/share/plannotator"
    cp -r "${finalAttrs.coreSkillsSource}/apps/skills/core" "$out/share/plannotator/skills"

    wrapProgram "$out/bin/plannotator" \
      --prefix PATH : ${
        lib.makeBinPath ([ git ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ xdg-utils ])
      }

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    "${../..}/packages/plannotator/update.ts"
    "${updateScriptZod}/index.js"
  ];

  meta = {
    description = "Browser-based plan, code, and document review for coding agents";
    homepage = "https://plannotator.ai";
    changelog = "https://github.com/backnotprop/plannotator/releases/tag/v${finalAttrs.version}";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    mainProgram = "plannotator";
    platforms = builtins.attrNames sources;
  };
})
