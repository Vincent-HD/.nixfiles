{ ... }:
{
  # nix-darwin: declarative Homebrew ownership for the macOS host.
  #
  # Feature modules declare the casks they own (codex in darwin.agentCodex, deskflow +
  # its tap in darwin.deskflow, ghostty in darwin.ghostty, rustdesk in darwin.rustdesk).
  # This module owns the remaining native GUI applications: self-updating apps and
  # privileged helpers that have no portable nixpkgs build.
  config.flake.modules.darwin.homebrew =
    { ... }:
    {
      homebrew = {
        enable = true;
        enableZshIntegration = true;

        # No formulae: every portable tool comes from Home Manager.
        casks = [
          "alt-tab"
          "audiorelay"
          "cleanshot"
          "jetbrains-toolbox"
          "moonlight"
          "orbstack"
          "raycast"
          "rectangle"
        ];

        # Mac App Store: applications with no Nix build. nix-darwin supplies
        # `mas` from nixpkgs and writes these into the Brewfile, so the list
        # stays under version control. Bitwarden is deliberately absent because
        # Home Manager owns it on both hosts; Tailscale stays here because the
        # macOS tunnel needs the App Store build's network extension.
        masApps = {
          "GarageBand" = 682658836;
          "GIPHY CAPTURE" = 668208984;
          "Keynote" = 409183694;
          "Numbers" = 409203825;
          "Pages" = 409201541;
          "Tailscale" = 1475387142;
          "iMovie" = 408981434;
        };
      };
    };
}
