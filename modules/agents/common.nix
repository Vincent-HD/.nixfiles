{ inputs, ... }:
{
  config.flake.modules.homeManager.agentCommon =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      papercutsPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.papercuts;

      # Papercuts defaults to a macOS-specific path upstream; keep one XDG path
      # across both hosts and preserve an explicit caller override.
      papercuts = pkgs.writeShellScriptBin "papercuts" ''
        export PAPERCUTS_HOME="''${PAPERCUTS_HOME:-${config.xdg.dataHome}/papercuts}"
        exec ${lib.getExe papercutsPackage} "$@"
      '';

      # rtk 0.43.0's own test suite denies two unused-code warnings on Darwin.
      # Its release binary builds successfully, so skip only that broken test phase.
      rtk = pkgs.rtk.overrideAttrs (_previousAttrs: {
        doCheck = false;
      });

      skillFiles = lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".agents/skills/${name}" {
          source = source;
        }
      ) config.custom.agentSetup.skills;

      # Keep long shared guidance in Markdown; this module only wires it into each client.
      commonAgentInstructions = builtins.readFile ./assets/common-agent-instructions.md;
    in
    {
      options.custom.agentSetup.skills = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
        default = { };
        description = ''
          Agent Skills installed once under the cross-client ~/.agents/skills standard.
          Codex and Cursor discover this location natively; VS Code is
          configured to use it by agentVscode.
        '';
      };

      config = {
        home = {
          packages = [
            papercuts
            rtk
          ];

          sessionVariables.PAPERCUTS_HOME = "${config.xdg.dataHome}/papercuts";

          file = skillFiles // {
            # Keep the complete shared guidance available to every AGENTS-aware client.
            "AGENTS.md".text = commonAgentInstructions;

            # Codex also receives RTK's official awareness document; RTK has no
            # programmatic Codex hook.
            ".codex/AGENTS.md".text = ''
              ${commonAgentInstructions}

              @${config.home.homeDirectory}/.codex/RTK.md
            '';
            ".codex/RTK.md".source = "${rtk.src}/hooks/codex/rtk-awareness.md";

          };
        };
      };
    };
}
