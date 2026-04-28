{ ... }:
{
  config.flake.modules.nixos.gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        protontricks.enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
      };

      # Steam download stalls can be caused by repeated DNS lookups.
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = true;
      };

      programs.gamemode.enable = true;
    };
}
