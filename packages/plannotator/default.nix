{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  makeWrapper,
  git,
  xdg-utils,
  packageUpdater,
}:

let
  # Release binary name and hash for each supported platform.
  artifacts = {
    "x86_64-linux" = {
      name = "plannotator-linux-x64";
      hash = "sha256-9AIcjEvDkPODFs8eVFM9KW/Wo68DP7KfDr9WD/W/sZk=";
    };
    "aarch64-linux" = {
      name = "plannotator-linux-arm64";
      hash = "sha256-jDmA++cRHZoNajmCu24lhHZWZrw2p039crisvNyNnAw=";
    };
    "x86_64-darwin" = {
      name = "plannotator-darwin-x64";
      hash = "sha256-HpEzMic+7yVnx8LtM192hOEMZ7rXb9fNyhmjyiBRAC0=";
    };
    "aarch64-darwin" = {
      name = "plannotator-darwin-arm64";
      hash = "sha256-8j7EtPlhWHTM0jtdHnPQPl1Z+XxK1t0JgI3UNnxySUw=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator";
  version = "0.29.3";

  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/plannotator"
    mkdir -p "$out/share/plannotator"
    cp -r "${finalAttrs.passthru.sources.core-skills}/apps/skills/core" "$out/share/plannotator/skills"

    wrapProgram "$out/bin/plannotator" \
      --prefix PATH : ${
        lib.makeBinPath ([ git ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ xdg-utils ])
      }

    runHook postInstall
  '';

  passthru = {
    # Every platform's fetch, plus the upstream shared Agent Skills at the same tag.
    sources =
      lib.mapAttrs (
        _system: artifact:
        fetchurl {
          url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/${artifact.name}";
          hash = artifact.hash;
        }
      ) artifacts
      // {
        core-skills = fetchFromGitHub {
          owner = "backnotprop";
          repo = "plannotator";
          rev = "v${finalAttrs.version}";
          hash = "sha256-5aL4Gcexgxlh2wXvrVb2Dh4vuHDC793z1NNduUdW9aY=";
        };
      };
    updateScript = packageUpdater.script {
      attr = "plannotator";
      file = ./default.nix;
      nixUpdateArgs = [ "--use-github-releases" ];
    };
  };

  meta = {
    description = "Browser-based plan, code, and document review for coding agents";
    homepage = "https://plannotator.ai";
    changelog = "https://github.com/backnotprop/plannotator/releases/tag/v${finalAttrs.version}";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    mainProgram = "plannotator";
    platforms = builtins.attrNames artifacts;
  };
})
