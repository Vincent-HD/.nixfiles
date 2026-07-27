{
  bun,
  fetchurl,
  lib,
  stdenvNoCC,
  undmg,
}:

let
  sources = {
    "aarch64-darwin" = {
      architecture = "arm64";
      hash = "sha256-d/bdi67FN3BBjIG5GI+O2GtYUeHLKW0iZRjOGxwuS0o=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cursor";
  version = "3.13.10";
  releaseCommit = "4f02290ccd9304f0e6bf8ee85f6e9106f02ac1f7";

  # Cursor's upstream Nix input currently pins an old macOS ARM disk image.
  src = fetchurl {
    url = "https://downloads.cursor.com/production/${finalAttrs.releaseCommit}/darwin/${source.architecture}/Cursor-darwin-${source.architecture}.dmg";
    hash = source.hash;
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = "Cursor.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Cursor.app"
    cp -R . "$out/Applications/Cursor.app"

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    ./update.ts
  ];

  meta = {
    description = "AI-powered code editor built on VS Code";
    homepage = "https://cursor.com";
    changelog = "https://www.cursor.com/changelog";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames sources;
  };
})
