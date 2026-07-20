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

      # GUI-launched agents do not reliably inherit the Home Manager profile PATH.
      # Keep Codex and Cursor Agent visible to Plannotator's review engine picker.
      plannotator = pkgs.symlinkJoin {
        name = "plannotator-${plannotatorPackage.version}-wrapped";
        paths = [ plannotatorPackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/plannotator" \
            --prefix PATH : "${config.home.profileDirectory}/bin:${lib.makeBinPath [ cursorAgentPackage ]}"
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
