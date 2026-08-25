{
  lib,
  curl,
  fetchurl,
  jq,
  makeWrapper,
  nix-update,
  nodejs_24,
  stdenvNoCC,
  writeShellScript,
}:

let
  # Resolve the current npm release, then let nix-update rewrite the version
  # and fixed-output hash in this package.
  updateScript = writeShellScript "update-portless" ''
    set -euo pipefail
    version="$(${lib.getExe curl} --fail --silent --show-error https://registry.npmjs.org/portless/latest | ${lib.getExe jq} -er '.version')"
    exec ${lib.getExe nix-update} --flake portless --version "$version"
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "portless";
  version = "0.15.6";

  # Portless publishes a self-contained npm package: the release tarball
  # contains the compiled CLI and has no runtime npm dependencies.
  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${finalAttrs.version}.tgz";
    hash = "sha256-SPFeXWPEd4RTTdletSAefmWM5D6uG3q5YNNLbWe5VIo=";
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

  passthru.updateScript = [ updateScript ];

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
