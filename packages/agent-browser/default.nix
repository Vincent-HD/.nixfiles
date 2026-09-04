{
  curl,
  fetchurl,
  jq,
  lib,
  nix-update,
  stdenvNoCC,
  writeShellScript,
}:

let
  sources = {
    "aarch64-darwin" = {
      suffix = "darwin-arm64";
      hash = "sha256-1oCnqWq4bpq50rVxsSkZt2HpNoKtHecUu9WshJyNfJw=";
    };
    "x86_64-darwin" = {
      suffix = "darwin-x64";
      hash = "sha256-2tPJ+eZ3kaRKdoqYhHUQxhp7VooEmcYCYyuK7kERAec=";
    };
    "x86_64-linux" = {
      suffix = "linux-x64";
      hash = "sha256-VtFRgeUeACE/kH/POXB8/Ha/qAT/IPWpNzZhxz+W3l4=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
  updateScript = writeShellScript "update-agent-browser" ''
    set -euo pipefail
    version="$(${lib.getExe curl} --fail --silent --show-error https://api.github.com/repos/vercel-labs/agent-browser/releases/latest | ${lib.getExe jq} -er '.tag_name | ltrimstr("v")')"
    exec ${lib.getExe nix-update} --flake agent-browser --version "$version" --use-github-releases
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "agent-browser";
  version = "0.36.0";

  src = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/releases/download/v${finalAttrs.version}/agent-browser-${source.suffix}";
    hash = source.hash;
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/agent-browser"
    runHook postInstall
  '';

  passthru.updateScript = [ updateScript ];

  meta = {
    description = "Fast native browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "agent-browser";
    platforms = builtins.attrNames sources;
  };
})
