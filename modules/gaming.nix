{ ... }:
{
  config.flake.modules.nixos.gaming =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        protontricks.enable = true;
        # MangoHud adds the in-game performance overlay for Steam titles.
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        # Steam launch options need Gamescope available inside Steam's runtime environment.
        extraPackages = [ pkgs.gamescope pkgs.mangohud ];
        # GameScope runs Steam inside a dedicated compositor session.
        gamescopeSession.enable = true;
      };

      # GameScope is the compositor used for Steam Deck-style fullscreen gaming sessions.
      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

      programs.gamemode.enable = true;

      # Make the MangoHud CLI available outside Steam as well.
      environment.systemPackages = [ pkgs.mangohud ];
    };
}
