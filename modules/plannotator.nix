{ inputs, ... }:
{
  config.flake.modules.homeManager.plannotator =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      plannotatorPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.plannotator;
      cursorAgentPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;

      #! TODO: Ugly workaround to remove when upstream is fixed
      # Plannotator forces Cursor's unavailable Linux sandbox for guided reviews.
      # Remove only that forced flag so Cursor can use its configured allowlist mode.
      cursorAgentPlannotatorAllowlist = pkgs.writeShellScriptBin "agent" ''
        set -eu
        args=()
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--sandbox" ] && [ "''${2-}" = "enabled" ]; then
            shift 2
          else
            args+=("$1")
            shift
          fi
        done
        exec ${lib.getExe cursorAgentPackage} "''${args[@]}"
      '';
      cursorAgentForPlannotator =
        if pkgs.stdenv.hostPlatform.isLinux then cursorAgentPlannotatorAllowlist else cursorAgentPackage;

      # GUI-launched agents do not reliably inherit the Home Manager profile PATH.
      # Keep Codex and Cursor Agent visible to Plannotator's review engine picker.
      plannotator = pkgs.symlinkJoin {
        name = "plannotator-${plannotatorPackage.version}-wrapped";
        paths = [ plannotatorPackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/plannotator" \
            --prefix PATH : "${
              lib.makeBinPath [ cursorAgentForPlannotator ]
            }:${config.home.profileDirectory}/bin:${lib.makeBinPath [ cursorAgentPackage ]}"
        '';
      };
    in
    {
      home.packages = [ plannotator ];

      # Register once; the shared agent module installs every skill canonically.
      custom.agentSetup.skills = {
        plannotator-review = "${plannotatorPackage}/share/plannotator/skills/plannotator-review";
        plannotator-annotate = "${plannotatorPackage}/share/plannotator/skills/plannotator-annotate";
        plannotator-last = "${plannotatorPackage}/share/plannotator/skills/plannotator-last";
      };
    };
}
