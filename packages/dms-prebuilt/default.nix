{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  makeWrapper,
  bun,
  updateScriptZod,
  dmsFlake,
}:
let
  version = "2.1.2";
  revision = "43255a46ea01e9d0de1fe8ce9897c0d71566b2a8";
  sources = {
    "x86_64-linux" = {
      asset = "dms-full-amd64.tar.gz";
      hash = "sha256-Pj7rI1tkFY69FMeBE6QXi8mUexpigjjXREkyfWns6po=";
    };
    "aarch64-linux" = {
      asset = "dms-full-arm64.tar.gz";
      hash = "sha256-F5Lmj88QTIvVuTR92MVEyN/NZLGIkJNkl7LR7Po/sWc=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
  archive = fetchurl {
    url = "https://github.com/duxlabs-dev/dux-shell/releases/download/v${version}/${source.asset}";
    hash = source.hash;
  };
  upstream = dmsFlake.packages.${stdenv.hostPlatform.system}.dms-shell;
in
upstream.overrideAttrs (previous: {
  # Preserve upstream QML, wrappers, completions and PAM wiring; replace only its Go build.
  version = version;
  src = archive;
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
      echo "DMS release and flake input differ; update them together using the DMS updater" >&2
      exit 1
    fi
    mkdir -p "$out/bin"
    tar -xzf "$src" -O ./bin/dms > "$out/bin/dms"
    chmod +x "$out/bin/dms"
    runHook postInstall
  '';
  passthru = (previous.passthru or { }) // {
    updateScript = [
      (lib.getExe bun)
      "${../..}/packages/dms-prebuilt/update.ts"
      "${updateScriptZod}/index.js"
    ];
  };
})
