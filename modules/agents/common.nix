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

      commonAgentInstructions = ''
        ## Nix environment

        This machine is managed by Nix. When a command-line tool is not available,
        run it temporarily with `comma` (for example, `, jq`) or use
        `nix run nixpkgs#jq -- <arguments>`. Do not install a tool globally just
        to complete a task.

        ## Response sections and feedback

        When proposing work, requesting feedback, or showcasing changes:

        - Use indexed items so the user can answer precisely: `1`, `2`, `3` for one
          section; `A1`, `A2`, `B1` when there are multiple sections.
        - Put completed or proposed changes under a clearly labeled `SHOWCASE`
          section when presenting them for review.
        - Add a clearly labeled `FEEDBACK NEEDED` section only when a real user
          question or decision is needed. Put every question there, indexed, and keep
          it separate from `SHOWCASE`; omit the section when there are no questions.
          
        ${papercutsInstructions}
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
