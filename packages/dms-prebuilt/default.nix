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
  version = "2.0.0";
  revision = "9b413296b16721f7679fb62e624cb1ed2433fa58";
  sources = {
    "x86_64-linux" = {
      asset = "dms-full-amd64.tar.gz";
      hash = "sha256-ooBW2/h0YXj2prB5YHcCNwW+y2A3xBgxETK9pXm90YU=";
    };
    "aarch64-linux" = {
      asset = "dms-full-arm64.tar.gz";
      hash = "sha256-Vd+GnwLFjq+s3/+N1myGs1seeRj0zwt3dTOldh0/3pI=";
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
