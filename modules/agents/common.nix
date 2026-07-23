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

      skillFiles = lib.mapAttrs' (
        name: source:
        lib.nameValuePair ".agents/skills/${name}" {
          source = source;
        }
      ) config.custom.agentSetup.skills;

      papercutsInstructions = ''
        <!-- papercuts:begin v1 -->
        ## Papercuts

        - Proactively record small, concrete friction encountered while working.
        - Use one or two sentences: state what was being done, what got in the way, and optionally a suspected cause or fix.
        - Record each distinct issue at most once per task.
        - Never include secrets, raw transcripts, or large command output.
        - Keep using the project's normal issue workflow for bugs; Papercuts is a friction journal.
        - Pipe the observation to `papercuts add --stdin --source codex`.
        - Continue the primary task if capture fails, and never record that failure as another papercut.
        - Never review transcripts automatically.
        <!-- papercuts:end -->
      '';
    in
    {
      options.custom.agentSetup.skills = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
        default = { };
        description = ''
          Agent Skills installed once under the cross-client ~/.agents/skills standard.
          Codex, Cursor, and OpenCode discover this location natively.
        '';
      };

      config = {
        home = {
          packages = [
            papercuts
            pkgs.rtk
          ];

          sessionVariables.PAPERCUTS_HOME = "${config.xdg.dataHome}/papercuts";

          file = skillFiles // {
            # Codex receives the portable Papercuts instructions and RTK's
            # official awareness document; RTK has no programmatic Codex hook.
            ".codex/AGENTS.md".text = ''
              ${papercutsInstructions}

              @${config.home.homeDirectory}/.codex/RTK.md
            '';
            ".codex/RTK.md".source = "${pkgs.rtk.src}/hooks/codex/rtk-awareness.md";

          };
        };
      };
    };
}
