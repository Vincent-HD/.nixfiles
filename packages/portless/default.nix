{
  lib,
  fetchurl,
  makeWrapper,
  nodejs_24,
  stdenvNoCC,
  packageUpdater,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "portless";
  version = "0.18.1";

  # Portless publishes a self-contained npm package: the release tarball
  # contains the compiled CLI and has no runtime npm dependencies.
  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${finalAttrs.version}.tgz";
    hash = "sha256-82LWgnCoR+gZO+lGwmxE7/DyZJ4zws/mCvE19xHgTKk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    packageDirectory="$out/lib/node_modules/portless"
    mkdir -p "$packageDirectory"
    tar -xzf "$src" --strip-components=1 -C "$packageDirectory"

    makeWrapper ${lib.getExe nodejs_24} "$out/bin/portless" \
      --add-flags "$packageDirectory/dist/cli.js"

    runHook postInstall
  '';

  # The npm `latest` tag names the release.
  passthru.updateScript = packageUpdater.script {
    attr = "portless";
    file = ./default.nix;
    latestVersion = "curl -fsS https://registry.npmjs.org/portless/latest | jq -r .version";
  };

  meta = {
    description = "Replace port numbers with stable, named local URLs";
    homepage = "https://github.com/vercel-labs/portless";
    changelog = "https://github.com/vercel-labs/portless/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "portless";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
