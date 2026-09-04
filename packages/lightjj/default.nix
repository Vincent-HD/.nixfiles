{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  jujutsu,
  git,
  gh,
  xdg-utils,
  openssh,
}:

let
  sources = {
    "aarch64-darwin" = {
      artifact = "lightjj-macos-arm64";
      hash = "sha256-/Qt5E8VRCxO8/DpTfyr6CWD2YdfQGdErkBjrZ+TJfws=";
    };
    "x86_64-linux" = {
      artifact = "lightjj-linux-x86_64";
      hash = "sha256-vzUf5k/nq5lGZGUOrLQPGSYRby6/uCWx6xNPdc1YOOw=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lightjj";
  version = "1.37.2";

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

  meta = {
    description = "Fast browser UI for Jujutsu version control";
    homepage = "https://github.com/chronologos/lightjj";
    license = lib.licenses.mit;
    mainProgram = "lightjj";
    platforms = builtins.attrNames sources;
  };
})
