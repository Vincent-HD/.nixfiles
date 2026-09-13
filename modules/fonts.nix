{ ... }:
{
  # NixOS: install the shared Nerd Font system-wide so every user, terminal, and
  # GUI toolkit can resolve it without a per-user font directory.
  config.flake.modules.nixos.fonts =
    { pkgs, ... }:
    {
      fonts.packages = [
        pkgs.nerd-fonts.caskaydia-mono
      ];
    };

  # nix-darwin: the same font family, installed into /Library/Fonts by activation.
  # Replaces the `font-caskaydia-mono-nerd-font` cask so both hosts match.
  config.flake.modules.darwin.fonts =
    { pkgs, ... }:
    {
      fonts.packages = [
        pkgs.nerd-fonts.caskaydia-mono
      ];
    };
}
