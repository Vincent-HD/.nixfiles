{
  lib,
  fetchPypi,
  python3Packages,
  packageUpdater,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "arch-ops-server";
  version = "3.4.0";
  format = "wheel";

  src = fetchPypi {
    pname = "arch_ops_server";
    version = finalAttrs.version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-KD/bU2Ole7aul4C/Og/5izl6mQd+QHmi13VwFbdZ/3o=";
  };

  dependencies = [
    python3Packages.beautifulsoup4
    python3Packages.httpx
    python3Packages.lxml
    python3Packages.markdownify
    python3Packages.mcp_1
  ];

  # The shared setup uses only the stdio server, so omit the HTTP launcher
  # whose optional Starlette and Uvicorn dependencies are intentionally absent.
  postInstall = ''
    rm "$out/bin/arch-ops-server-http"
  '';

  pythonImportsCheck = [ "arch_ops_server" ];
  doCheck = false;

  # PyPI names the current release of the universal wheel.
  passthru.updateScript = packageUpdater.script {
    attr = "arch-ops-server";
    file = ./default.nix;
    latestVersion = "curl -fsS https://pypi.org/pypi/arch-ops-server/json | jq -r .info.version";
  };

  meta = {
    description = "MCP server for the Arch Linux ecosystem";
    homepage = "https://pypi.org/project/arch-ops-server/";
    license = [
      lib.licenses.gpl3Only
      lib.licenses.mit
    ];
    mainProgram = "arch-ops-server";
    platforms = lib.platforms.unix;
  };
})
