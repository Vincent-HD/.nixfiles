{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_24,
}:
let
  # A generated lockfile pins @open-pencil/mcp and its npm closure; keep it in step with the app.
  closure = lib.importJSON ./package.json;
in
buildNpmPackage (finalAttrs: {
  pname = "open-pencil-mcp";
  version = closure.version;
  nodejs = nodejs_24;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  npmDepsHash = "sha256-bevkU9aJ1pwStW2t9kUpyz0ALoooa8uQWGvub/PVn5o=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/open-pencil-mcp" "$out/bin"
    cp -R node_modules "$out/lib/open-pencil-mcp/"
    packageDirectory="$out/lib/open-pencil-mcp/node_modules/@open-pencil/mcp"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/openpencil-mcp" \
      --add-flags "$packageDirectory/dist/stdio.mjs"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/openpencil-mcp-http" \
      --add-flags "$packageDirectory/dist/index.mjs"
    runHook postInstall
  '';

  meta = {
    description = "MCP server that lets coding agents drive a running OpenPencil app";
    homepage = "https://openpencil.dev/developers/mcp-server";
    license = lib.licenses.mit;
    mainProgram = "openpencil-mcp";
    platforms = lib.platforms.unix;
  };
})
