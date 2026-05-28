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

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lightjj";
  version = "1.29.0";

  src = fetchurl {
    url = "https://github.com/chronologos/lightjj/releases/download/v${finalAttrs.version}/lightjj-linux-x86_64";
    hash = "sha256-hEa0AFWhURKIbfzgLnQWEfD1iGXkeVurM+fLPqDMxH4=";
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
    platforms = [ "x86_64-linux" ];
  };
})
