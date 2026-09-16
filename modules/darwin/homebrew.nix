{ ... }:
{
  # nix-darwin: declarative Homebrew ownership for the macOS host.
  #
  # Feature modules declare the casks they own (audiorelay and its BlackHole audio
  # drivers in darwin.audioRelay, codex in darwin.agentCodex, deskflow + its tap in
  # darwin.deskflow, ghostty in darwin.ghostty, rustdesk in darwin.rustdesk).
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
          "cleanshot"
          "jetbrains-toolbox"
          "moonlight"
          "orbstack"
          "raycast"
          "rectangle"
        ];

        # Mac App Store: the applications nothing else can supply. nix-darwin
        # supplies `mas` from nixpkgs and writes these into the Brewfile, so the
        # list stays under version control.
        #
        # Keynote, Numbers, and Pages have no cask and no nixpkgs build, so the
        # App Store is the only source. Tailscale stays here rather
        # than moving to the `tailscale-app` cask: nixpkgs ships only the CLI on
        # Darwin, both distributions carry the same version, and the cask still
        # installs through `sudo` with a system extension to re-approve while
        # marking itself `auto_updates`, so Homebrew would control nothing.
        #
        # Bitwarden is deliberately absent because Home Manager owns it on both
        # hosts. GarageBand and iMovie are absent too and are neither declared
        # nor managed; they were removed from the machine. Note that removing an
        # entry here never uninstalls the application, even under
        # `onActivation.cleanup = "uninstall"`, because the App Store owns the
        # install.
        masApps = {
          "Keynote" = 409183694;
          "Numbers" = 409203825;
          "Pages" = 409201541;
          "Tailscale" = 1475387142;
        };
      };
    };
}
