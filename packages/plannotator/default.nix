{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  makeWrapper,
  bun,
  git,
  xdg-utils,
}:

let
  sources = {
    "x86_64-linux" = {
      artifact = "plannotator-linux-x64";
      hash = "sha256-YpXiRnfgMqvsEIzGsCh12y+G0oLf3l181yW1uS6/9ow=";
    };
    "aarch64-linux" = {
      artifact = "plannotator-linux-arm64";
      hash = "sha256-jJkVjFxWj6lqBojruLBiRpBfvZNnaJ/LZmpqRx+u1KU=";
    };
    "x86_64-darwin" = {
      artifact = "plannotator-darwin-x64";
      hash = "sha256-kw9Slut12IX0S/8hMj4X+HYnapO58KDCQ/7GXS+0OKo=";
    };
    "aarch64-darwin" = {
      artifact = "plannotator-darwin-arm64";
      hash = "sha256-MtKPrN80xRGYLTjyK121O3FSdTbS0PwI/sHPjxinYlc=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator";
  version = "0.27.3";

  src = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/${source.artifact}";
    hash = source.hash;
  };

  # Keep the upstream shared Agent Skills aligned with the packaged binary.
  coreSkillsSource = fetchFromGitHub {
    owner = "backnotprop";
    repo = "plannotator";
    rev = "v${finalAttrs.version}";
    hash = "sha256-h/5xMnpoQeTuF4H+BO4TZDXVGjUSJwvARz/hkrCnVZ4=";
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
    ./update.ts
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
