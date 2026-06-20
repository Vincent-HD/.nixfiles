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

      programs.gamemode.enable = true;

      # Fix Steam slow downloads by enabling systemd-resolved
      # See: https://www.reddit.com/r/NixOS/comments/1pmsy8u/steam_really_slow_downloads/
      services.resolved.enable = true;
    };
}
