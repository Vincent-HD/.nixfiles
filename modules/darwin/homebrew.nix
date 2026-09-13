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
      };
    };
}
