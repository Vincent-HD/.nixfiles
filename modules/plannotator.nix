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

      # Shared Agent Skills are discovered globally by both Codex and Cursor.
      home.file.".agents/skills/plannotator-review".source =
        "${plannotatorPackage}/share/plannotator/skills/plannotator-review";
      home.file.".agents/skills/plannotator-annotate".source =
        "${plannotatorPackage}/share/plannotator/skills/plannotator-annotate";
      home.file.".agents/skills/plannotator-last".source =
        "${plannotatorPackage}/share/plannotator/skills/plannotator-last";
    };
}
