{ ... }:
{
  # Home Manager: Ghostty terminal emulator with the configuration shared by both
  # hosts. nixpkgs only builds Ghostty on Linux, so macOS leaves the package null
  # and ownership of the app bundle stays with the Homebrew cask below.
  config.flake.modules.homeManager.ghostty =
    { pkgs, lib, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.ghostty else null;
        settings = {
          # Close Ghostty surfaces without asking for confirmation.
          confirm-close-surface = "false";
          # Do not return OSC color probes that can leak into interactive input.
          osc-color-report-format = "none";
          # Use Zsh-compatible Meta sequences for word movement with modified arrows.
          keybind = [
            "alt+arrow_left=esc:b"
            "alt+arrow_right=esc:f"
            "ctrl+arrow_left=esc:b"
            "ctrl+arrow_right=esc:f"
          ];
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          gtk-titlebar = "false";
          window-decoration = "false";
          window-show-tab-bar = "never";
        };
      };
    };

  # nix-darwin: Ghostty is not packaged for Darwin in nixpkgs, so the macOS app
  # comes from Homebrew while the Home Manager module still writes the shared config.
  config.flake.modules.darwin.ghostty =
    { ... }:
    {
      homebrew = {
        enable = true;
        casks = [ "ghostty" ];
      };
    };
}
