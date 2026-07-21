{
  lib,
  stdenvNoCC,
  fetchurl,
  bun,
  makeWrapper,
}:

let
  pname = "opencodex";
  version = "2.7.30";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bitkyc08/opencodex/-/opencodex-${version}.tgz";
    hash = "sha256-jvSi4itS2ATvu5Ariyflyx1eoy3+DrV+rdMerB8X2i0=";
  };

  bunLock = fetchurl {
    url = "https://raw.githubusercontent.com/lidge-jun/opencodex/v${version}/bun.lock";
    hash = "sha256-HNfTmO9RgVhcP3jVLlySlL/WZhR9rO9qqf2zv35Ln0g=";
  };

  # The npm package omits its lockfile, so fetch the release-matching one.
  bunDeps = stdenvNoCC.mkDerivation {
    name = "${pname}-${version}-bun-deps";
    inherit src;
    sourceRoot = "package";

    nativeBuildInputs = [ bun ];

    postPatch = ''
      cp "${bunLock}" bun.lock
    '';

    buildPhase = ''
      runHook preBuild

      bun install --frozen-lockfile --production --backend=copyfile

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # The Nix wrapper supplies Bun, so do not retain upstream's unused npm
      # copy of the Bun runtime or Bun's install cache.
      rm -rf node_modules/.cache node_modules/bun node_modules/@oven
      mkdir -p "$out"
      cp -r node_modules "$out/node_modules"

      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHash = "sha256-Yf4JQn2EMb/En0YZGia6yezoJOn8WNIcA9lIHcQYzXw=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version src;
  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    package_out="$out/lib/opencodex"
    mkdir -p "$package_out"
    cp -r bin gui src package.json "$package_out/"
    cp -r "${bunDeps}/node_modules" "$package_out/node_modules"

    makeWrapper ${lib.getExe bun} "$out/bin/ocx" \
      --add-flags "$package_out/src/cli/index.ts"
    ln -s ocx "$out/bin/opencodex"

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe bun)
    ./update.ts
  ];

  meta = {
    description = "Universal provider proxy for OpenAI Codex and Claude Code";
    homepage = "https://github.com/lidge-jun/opencodex";
    changelog = "https://github.com/lidge-jun/opencodex/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "ocx";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
})
