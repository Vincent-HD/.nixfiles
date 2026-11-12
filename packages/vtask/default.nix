{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
}:
let
  manifest = builtins.fromJSON (builtins.readFile ./package.json);
  releaseManifest = builtins.fromJSON (builtins.readFile ./bin/manifest.json);
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
  # Fingerprint of everything compiled into the release, matched against bin/manifest.json.
  sourceHash = builtins.hashString "sha256" (
    lib.concatMapStrings (
      file: "${file}\n${builtins.hashFile "sha256" (./. + "/${file}")}\n"
    ) sourceFiles
  );
  binary = ./. + "/bin/${system}/vtask";
  artifact =
    releaseManifest.binaries.${system}
      or (throw "vtask: bin/manifest.json has no binary for ${system}; run `pnpm --dir packages/vtask release`.");
in
# Only the checked-in Git LFS release is packaged; stale or missing binaries fail with the fix to run.
assert lib.assertMsg (
  releaseManifest.version == manifest.version && releaseManifest.sourceHash == sourceHash
) "vtask: bin/ is stale for the current sources; run `pnpm --dir packages/vtask release`.";
assert lib.assertMsg (
  builtins.pathExists binary && builtins.hashFile "sha256" binary == artifact.sha256
) "vtask: bin/${system}/vtask does not match bin/manifest.json; run `git lfs pull`.";
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vtask";
  version = manifest.version;
  src = binary;

  # Linux binaries need Nix's ELF interpreter.
  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Bun's embedded executable payload must survive Nix's ELF fixup phase.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/vtask"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/vtask" --version | grep -Fx 'vtask v${finalAttrs.version}'
    runHook postInstallCheck
  '';

  passthru = {
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
