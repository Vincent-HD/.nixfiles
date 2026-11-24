{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  makeWrapper,
  packageUpdater,
  dmsFlake,
}:
let
  version = "2.1.2";
  revision = "43255a46ea01e9d0de1fe8ce9897c0d71566b2a8";
  # Release archive and hash for each supported platform.
  artifacts = {
    "x86_64-linux" = {
      asset = "dms-full-amd64.tar.gz";
      hash = "sha256-Pj7rI1tkFY69FMeBE6QXi8mUexpigjjXREkyfWns6po=";
    };
    "aarch64-linux" = {
      asset = "dms-full-arm64.tar.gz";
      hash = "sha256-F5Lmj88QTIvVuTR92MVEyN/NZLGIkJNkl7LR7Po/sWc=";
    };
  };
  # Every platform's fetch, so one host can refresh all hashes.
  sources = lib.mapAttrs (
    _system: artifact:
    fetchurl {
      url = "https://github.com/duxlabs-dev/dux-shell/releases/download/v${version}/${artifact.asset}";
      hash = artifact.hash;
    }
  ) artifacts;
  upstream = dmsFlake.packages.${stdenv.hostPlatform.system}.dms-shell;
in
upstream.overrideAttrs (previous: {
  # Preserve upstream QML, wrappers, completions and PAM wiring; replace only its Go build.
  version = version;
  src = sources.${stdenv.hostPlatform.system};
  dontUnpack = true;
  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];
  goModules = null;
  configurePhase = "true";
  buildPhase = "true";
  doCheck = false;
  # The upstream CLI is statically linked; preserve its embedded resources unchanged.
  dontStrip = true;
  dontPatchELF = true;
  installPhase = ''
    runHook preInstall
    if [ "${dmsFlake.rev or ""}" != "${revision}" ]; then
      echo "DMS release and flake input differ; update them together with 'nix run .#update-pins -- --only dms-prebuilt'" >&2
      exit 1
    fi
    mkdir -p "$out/bin"
    tar -xzf "$src" -O ./bin/dms > "$out/bin/dms"
    chmod +x "$out/bin/dms"
    runHook postInstall
  '';
  passthru = (previous.passthru or { }) // {
    sources = sources;
    # The release must match the `dms` flake input (QML and modules); see post-update.ts.
    updateScript = packageUpdater.script {
      attr = "dms-prebuilt";
      file = ./default.nix;
      nixUpdateArgs = [ "--use-github-releases" ];
      postUpdate = ./post-update.ts;
    };
  };
})
