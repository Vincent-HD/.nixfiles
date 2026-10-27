{
  lib,
  stdenvNoCC,
  fetchzip,
  fetchPnpmDeps,
  pnpm_11,
  pnpmConfigHook,
  nodejs_24,
  writableTmpDirAsHomeHook,
  enableUsagePatch ? true,
  enableJjPanel ? false,
  enableTemporaryThreads ? false,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "t3code-web";
  version = "0.1.2-nightly.20261022.3541";

  src = fetchzip {
    url = "https://github.com/pingdotgg/t3code/archive/refs/tags/v${finalAttrs.version}.tar.gz";
    hash = "sha256-C5l7541kanlsukhswrAEu8GFpr/YpWDnofJ5dlg7+LM=";
  };

  outputs = [ "out" ] ++ lib.optional (enableUsagePatch || enableJjPanel) "server";
  # Preserve all hunk context; feature intent and repair guidance live in patches/README.md.
  patchFlags = [
    "-p1"
    "--fuzz=0"
  ];
  patches =
    lib.optional enableUsagePatch ./patches/composer-usage.patch
    ++ lib.optional enableJjPanel ./patches/jj-panel.patch
    ++ lib.optional enableTemporaryThreads ./patches/temporary-threads.patch;
  # The unchanged dependency graph already has notices in the pinned desktop artifact.
  postPatch = ''
    substituteInPlace apps/web/vite.config.ts \
      --replace-fail '        : thirdPartyLicensesPlugin({' '        : false && thirdPartyLicensesPlugin({'
  '';
  nativeBuildInputs = [
    nodejs_24
    pnpm_11
    pnpmConfigHook
    writableTmpDirAsHomeHook
  ];
  pnpmWorkspaces = [ "t3..." ];
  pnpmInstallFlags = [ "--ignore-scripts" ];
  pnpmDeps = fetchPnpmDeps {
    pname = finalAttrs.pname;
    version = finalAttrs.version;
    src = finalAttrs.src;
    pnpm = pnpm_11;
    pnpmWorkspaces = finalAttrs.pnpmWorkspaces;
    fetcherVersion = 4;
    hash = "sha256-vUfwaOFB6DsdH0UHGDjspL8F/GDU+I/cOBNBSV5wwk8=";
  };

  env.APP_VERSION = finalAttrs.version;
  env.T3CODE_WEB_SOURCEMAP = "false";
  buildPhase = ''
    runHook preBuild
    # Upstream documents these public identifiers for production T3 Connect builds.
    cp .env.example .env
    node --input-type=module -e '
      import fs from "node:fs";
      const file = "apps/server/package.json";
      const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
      pkg.version = process.env.APP_VERSION;
      fs.writeFileSync(file, JSON.stringify(pkg));
    '
    pnpm --config.verify-deps-before-run=false --filter @t3tools/web build
    ${lib.optionalString (
      enableUsagePatch || enableJjPanel
    ) "pnpm --config.verify-deps-before-run=false --filter t3 build:bundle"}
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    cp -R apps/web/dist "$out"
    ${lib.optionalString (enableUsagePatch || enableJjPanel) ''
      cp -R apps/server/dist "$server"
      test -f "$server/bin.mjs"
      test -f "$server/claude-history-worker.mjs"
    ''}
    runHook postInstall
  '';
  meta = {
    description = "T3 Code renderer and optional server with independently selected local patches";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
