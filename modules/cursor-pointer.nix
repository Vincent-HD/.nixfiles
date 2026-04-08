{ ... }:
{
  # Home Manager: pointer (mouse cursor) theme for Wayland + GTK so clients match
  # `programs.niri.settings.cursor` and pick up XCURSOR_* / GTK settings.
  # Upstream reference name: references/neoelectron-nixfiles/modules/cursor.nix
  config.flake.modules.homeManager.cursorPointer =
    { pkgs, lib, ... }:
    {
      home.pointerCursor = {
        name = lib.mkDefault "Adwaita";
        package = lib.mkDefault pkgs.adwaita-icon-theme;
        size = lib.mkDefault 24;
        gtk.enable = true;
      };

      gtk.enable = true;
    };
}
