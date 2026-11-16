{ ... }:
{
  # Home Manager: Kdenlive video editor (replaces FilmCraft). Video files keep the
  # existing player as default; only Kdenlive projects open in the editor.
  config.flake.modules.homeManager.kdenlive =
    { pkgs, lib, ... }:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      home.packages = [ pkgs.kdePackages.kdenlive ];
      xdg.mimeApps = {
        enable = true;
        defaultApplications."application/x-kdenlive" = [ "org.kde.kdenlive.desktop" ];
      };
    };

  # nix-darwin: nixpkgs builds Kdenlive for Linux only, so macOS uses the cask.
  config.flake.modules.darwin.kdenlive =
    { ... }:
    {
      homebrew.casks = [ "kdenlive" ];
    };
}
