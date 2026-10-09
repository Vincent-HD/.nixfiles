{
  lib,
  stdenvNoCC,
  bun,
  nodejs_24,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  writableTmpDirAsHomeHook,
  autoPatchelfHook,
  preferPrebuilt ? true,
}:
let
  manifest = builtins.fromJSON (builtins.readFile ./package.json);
  system = stdenvNoCC.hostPlatform.system;
  sourceFiles = lib.sort builtins.lessThan (
    [
      "package.json"
      "pnpm-lock.yaml"
      "pnpm-workspace.yaml"
      "assets/tasks.schema.json"
    ]
    ++ map (file: "src/${file}") (
      lib.filter (file: lib.hasSuffix ".ts" file) (builtins.attrNames (builtins.readDir ./src))
    )
  );
  # Rebuild when any executable source, dependency lock, or build recipe changes.
  sourceHash = builtins.hashString "sha256" (
    lib.concatMapStrings (
      file: "${file}\n${builtins.hashFile "sha256" (./. + "/${file}")}\n"
    ) sourceFiles
  );
  releaseManifest =
    if builtins.pathExists ./bin/manifest.json then
      builtins.fromJSON (builtins.readFile ./bin/manifest.json)
    else
      { };
  binary = ./. + "/bin/${system}/vtask";
  artifact = releaseManifest.binaries.${system} or null;
  # A Git LFS pointer or stale binary automatically takes the source-build path.
  usePrebuilt =
    preferPrebuilt
    && (releaseManifest.version or "") == manifest.version
    && (releaseManifest.sourceHash or "") == sourceHash
    && (releaseManifest.compilerVersion or "") == bun.version
    && artifact != null
    && builtins.pathExists binary
    && builtins.hashFile "sha256" binary == artifact.sha256;
  source = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./src
      ./assets/tasks.schema.json
      ./package.json
      ./pnpm-lock.yaml
      ./pnpm-workspace.yaml
    ];
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vtask";
  version = manifest.version;
  src = if usePrebuilt then binary else source;

  nativeBuildInputs =
    lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ]
    ++ lib.optionals (!usePrebuilt) [
      bun
      nodejs_24
      pnpm
      pnpmConfigHook
      writableTmpDirAsHomeHook
    ];

  pnpmDeps =
    if usePrebuilt then
      null
    else
      fetchPnpmDeps {
        pname = finalAttrs.pname;
        version = finalAttrs.version;
        src = source;
        pnpm = pnpm;
        fetcherVersion = 4;
        pnpmInstallFlags = [ "--prod" ];
        hash = "sha256-dwHisg9CE562Z/TEmtopJvON/OAjOUXdV/TjM1lv0lg=";
      };
  pnpmInstallFlags = [ "--prod" ];

  dontUnpack = usePrebuilt;
  dontConfigure = usePrebuilt;
  dontBuild = usePrebuilt;
  # Bun's embedded executable payload must survive Nix's ELF fixup phase.
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    bun src/build.ts --native --target ${lib.escapeShellArg system}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ${if usePrebuilt then "$src" else "dist/${system}/vtask"} "$out/bin/vtask"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/vtask" --version | grep -Fx 'vtask v${finalAttrs.version}'
    runHook postInstallCheck
  '';

  passthru = {
    usesPrebuilt = usePrebuilt;
    sourceHash = sourceHash;
  };
  meta = {
    description = "Pick and run VS Code tasks with Effect prompts and workspace-aware execution";
    mainProgram = "vtask";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
})
