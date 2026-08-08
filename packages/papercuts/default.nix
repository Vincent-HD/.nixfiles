{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  gitMinimal,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "papercuts";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "claylevering";
    repo = "papercuts";
    rev = "v${finalAttrs.version}";
    hash = "sha256-CiYUpquo/QZMkDSv8aZEfdXEusiINIOaNc3sf7J0JMs=";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  dontConfigure = true;

  # Compile the zero-runtime-dependency Bun application into one executable.
  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    bun build \
      --compile \
      --no-compile-autoload-dotenv \
      --no-compile-autoload-bunfig \
      --outfile papercuts \
      src/index.ts

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 papercuts "$out/bin/papercuts"
    wrapProgram "$out/bin/papercuts" \
      --prefix PATH : ${lib.makeBinPath [ gitMinimal ]}

    runHook postInstall
  '';

  meta = {
    description = "Local-first friction journal for AI coding agents";
    homepage = "https://github.com/claylevering/papercuts";
    changelog = "https://github.com/claylevering/papercuts/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "papercuts";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
