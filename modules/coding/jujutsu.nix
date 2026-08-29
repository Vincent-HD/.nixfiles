{ inputs, ... }:
{
  config.flake.modules.homeManager.codingJujutsu =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.jj-ryu
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.lightjj
        inputs.jjui.packages.${pkgs.stdenv.hostPlatform.system}.jjui
      ];

      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Vincent-HD";
            email = "vincenthoudan@gmail.com";
          };
          ui."conflict-marker-style" = "git";
          # Match astahmer: default new revisions to "wip" instead of an empty description.
          templates.new_description = ''"wip"'';
          remotes.origin."auto-track-bookmarks" = "*";
        };
      };
    };
}
