{ inputs, ... }:
{
  config.flake.modules.homeManager.codingJujutsu =
    { pkgs, ... }:
    {
      home.packages = [
        inputs.self.packages.${pkgs.system}.jj-ryu
        pkgs.jujutsu
        inputs.self.packages.${pkgs.system}.lightjj
        inputs.jjui.packages.${pkgs.system}.jjui
      ];

      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Vincent-HD";
            email = "vincenthoudan@gmail.com";
          };
          ui."conflict-marker-style" = "git";
          remotes.origin."auto-track-bookmarks" = "*";
        };
      };
    };
}
