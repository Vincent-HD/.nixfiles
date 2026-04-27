{ ... }:
{
  # Home Manager side: Work tools
  config.flake.modules.homeManager.work =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.doppler
        pkgs.awscli2
        pkgs.ssm-session-manager-plugin
        pkgs.jetbrains.datagrip
      ];
    };
}
