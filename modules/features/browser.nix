{ ... }:
{
  # Home Manager side: web browser
  flake.modules.homeManager.browser =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        brave
      ];
    };
}
