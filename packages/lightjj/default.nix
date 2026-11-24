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
  packageUpdater,
}:

let
  # Release artifact name and hash for each supported platform.
  artifacts = {
    "aarch64-darwin" = {
      name = "lightjj-macos-arm64";
      hash = "sha256-EejSS1x95/8AnSKrzNVR8mGAl8Vi65HSAXpGbVYUXvs=";
    };
    "x86_64-linux" = {
      name = "lightjj-linux-x86_64";
      hash = "sha256-lL92ES31t5qw3z47T0KtypfxPIt651RI3ykyI1QOyIg=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lightjj";
  version = "1.42.0";

  src = finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system};

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

  passthru = {
    # Every platform's fetch, so one host can refresh all hashes.
    sources = lib.mapAttrs (
      _system: artifact:
      fetchurl {
        url = "https://github.com/chronologos/lightjj/releases/download/v${finalAttrs.version}/${artifact.name}";
        hash = artifact.hash;
      }
    ) artifacts;
    updateScript = packageUpdater.script {
      attr = "lightjj";
      file = ./default.nix;
      nixUpdateArgs = [ "--use-github-releases" ];
    };
  };

  meta = {
    description = "Fast browser UI for Jujutsu version control";
    homepage = "https://github.com/chronologos/lightjj";
    license = lib.licenses.mit;
    mainProgram = "lightjj";
    platforms = builtins.attrNames artifacts;
  };
})
