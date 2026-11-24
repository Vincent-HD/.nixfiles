{ inputs, ... }:
{
  # Home Manager: OpenPencil design editor (replaces FigCraft) with its agent tooling.
  # The app runs Claude Code and Codex through ACP adapters and exposes the canvas
  # through the version-matched MCP server; both must be on PATH.
  config.flake.modules.homeManager.openPencil =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      flakePackages = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
      openPencil = flakePackages.open-pencil;
      lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
      appBundle = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/OpenPencil.app";
    in
    lib.mkMerge [
      {
        home.packages = [
          openPencil
          flakePackages.open-pencil-mcp
          pkgs.claude-agent-acp
          pkgs.codex-acp
        ];
      }

      # Linux: Figma and pen.dev files plus openpencil:// links open in OpenPencil.
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        xdg.mimeApps = {
          enable = true;
          defaultApplications = lib.genAttrs [
            "application/x-figma"
            "application/x-pencil-pen"
            "x-scheme-handler/openpencil"
          ] (_mimeType: [ openPencil.passthru.desktopFile ]);
        };
      })

      # macOS: the bundle declares .fig/.pen by extension only, so associate by extension.
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.activation.openPencilFileAssociations = lib.hm.dag.entryAfter [ "copyApps" ] ''
          run ${lsregister} -f "${appBundle}"
          run ${lib.getExe pkgs.duti} -s ${openPencil.passthru.bundleIdentifier} .fig all
          run ${lib.getExe pkgs.duti} -s ${openPencil.passthru.bundleIdentifier} .pen all
        '';
      })
    ];
}
