{
  lib,
  buildNpmPackage,
  bun,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  nodejs_24,
}:

buildNpmPackage (finalAttrs: {
  pname = "codeburn";
  version = "0.9.28";
  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  # The repository tag supplies the lockfile used to materialize Codeburn's
  # production dependencies; the npm artifact supplies the published CLI and
  # dashboard bundle without rebuilding against mutable pricing endpoints.
  src = fetchFromGitHub {
    owner = "getagentseal";
    repo = "codeburn";
    rev = "v${finalAttrs.version}";
    hash = "sha256-NwLg4QIaabmf5YiGsE+N9PNx3TuW6RZV+Yyj1/anr1Y=";
  };

  npmArtifact = fetchurl {
    url = "https://registry.npmjs.org/codeburn/-/codeburn-${finalAttrs.version}.tgz";
    hash = "sha512-fl9u2m2n8n+cY6FheIY/jthw4GeuUtM38NfX3KR3Ljj2X7GFcUCfCGeRrnIaaM+aqmMLOw70Uy2BGnzoQgQlPQ==";
  };

  npmDepsHash = "sha256-F/d/xn3COOdM0lpog66bo7xJT4GBwZbHKsyrKuKCdgY=";
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    packageDirectory="$out/lib/node_modules/codeburn"
    mkdir -p "$packageDirectory"
    tar -xzf "${finalAttrs.npmArtifact}" --strip-components=1 -C "$packageDirectory"
    cp -r node_modules "$packageDirectory/node_modules"

    makeWrapper ${lib.getExe nodejs_24} "$out/bin/codeburn" \
      --add-flags "$packageDirectory/dist/cli.js"

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    ./update.ts
  ];

  meta = {
    description = "Local-first CLI and MCP server for analyzing AI coding-agent spend";
    homepage = "https://github.com/getagentseal/codeburn";
    changelog = "https://github.com/getagentseal/codeburn/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "codeburn";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
