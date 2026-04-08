{ ... }:
{
  # Home Manager side: KDE Connect
  config.flake.modules.homeManager.kdeConnect =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.kdePackages.kdeconnect-kde
      ];
    };
}
