{ ... }:
{
  # Home Manager side: Vicinae launcher
  config.flake.modules.homeManager.vicinae =
    { pkgs, ... }:
    {
      programs.vicinae = {
        enable = true;
        package = pkgs.vicinae;
        systemd.enable = true;
        systemd.autoStart = true;
      };
    };
}
