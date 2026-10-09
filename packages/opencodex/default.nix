{
  lib,
  stdenvNoCC,
  fetchurl,
  bun,
  makeWrapper,
  updateScriptZod,
}:

let
  pname = "opencodex";
  version = "2.81.0";
  targetPlatforms = {
    "aarch64-darwin" = {
      os = "darwin";
      cpu = "arm64";
    };
    "x86_64-linux" = {
      os = "linux";
      cpu = "x64";
    };
  };
  bunDepsHashes = {
    "aarch64-darwin" = "sha256-BJ7oaKKQ+QP2v7f2LiL7sP8JJksb5+MTfwAphxl2XkQ=";
    "x86_64-linux" = "sha256-NwnxZQ3UgSPpv7wtWIUsm66Qna0F/79lgKgH94CYjyw=";
  };
  src = fetchurl {
    url = "https://registry.npmjs.org/@bitkyc08/opencodex/-/opencodex-${version}.tgz";
    hash = "sha256-hhckJB28+QZJQt1qa7g/NN0zgBQAB6bnh5FgabQzir0=";
  };

  # The npm package omits its lockfile, so fetch the release-matching one.
  bunLock = fetchurl {
    url = "https://raw.githubusercontent.com/lidge-jun/opencodex/v${version}/bun.lock";
    hash = "sha256-6B58rZq7oSUVhS0zWOb0fvPxWkxMpTOceEIIhUPSPdk=";
  };

  mkBunDeps =
    targetSystem: targetPlatform:
    stdenvNoCC.mkDerivation {
      name = "${pname}-${version}-bun-deps-${targetSystem}";
      inherit src;
      sourceRoot = "package";

      nativeBuildInputs = [ bun ];

      postPatch = ''
        cp "${bunLock}" bun.lock
      '';

      buildPhase = ''
        runHook preBuild

        # Nix supplies Bun at runtime; do not run the npm `bun` package's
        # postinstall, which tries to download another platform binary.
        bun install --frozen-lockfile --production --backend=copyfile --ignore-scripts \
          --os=${targetPlatform.os} --cpu=${targetPlatform.cpu}

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        # The Nix wrapper supplies Bun, so do not retain upstream's unused npm
        # copy of the Bun runtime or Bun's install cache.
        rm -rf node_modules/.cache node_modules/bun node_modules/@oven
        rm -f node_modules/.bin/bun node_modules/.bin/bunx
        mkdir -p "$out"
        cp -r node_modules "$out/node_modules"

        runHook postInstall
      '';

      outputHashMode = "recursive";
      outputHash = bunDepsHashes.${targetSystem};
    };
  bunDepsBySystem = builtins.mapAttrs mkBunDeps targetPlatforms;
  bunDeps = bunDepsBySystem.${stdenvNoCC.hostPlatform.system};

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
    "${updateScriptZod}/index.js"
  ];
  passthru.bunDepsBySystem = bunDepsBySystem;

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
