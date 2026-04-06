{ ... }:
{
  # NixOS side: KDE Plasma 6 desktop environment
  flake.modules.nixos.plasma =
    { ... }:
    {
      services.xserver.enable = true;
      services.displayManager.sddm.enable = true;
      services.displayManager.sddm.wayland.enable = true; # fixes TTY mismatch after login on NVIDIA
      services.displayManager.sddm.autoNumlock = true; # seems broken @see https://github.com/NixOS/nixpkgs/issues/403259
      services.desktopManager.plasma6.enable = true;
    };

  # Home Manager side: KDE user packages
  flake.modules.homeManager.plasma =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kdePackages.kate
      ];
    };
}
