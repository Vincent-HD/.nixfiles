{ ... }:
{
  config.flake.modules.darwin.homebrew =
    { ... }:
    {
      homebrew = {
        enable = true;
        enableZshIntegration = true;

        taps = [
          "homebrew/services"
        ];

        # Preserve the current Homebrew formula ownership during the first migration.
        brews = [
          "jq"
          "mas"
          "thefuck"
        ];

        casks = [
          "alt-tab"
          "audiorelay"
          "blackhole-16ch"
          "blackhole-2ch"
          "brave-browser"
          "bruno"
          "cleanshot"
          "cursor"
          "dbeaver-community"
          "discord"
          "font-caskaydia-mono-nerd-font"
          "ghostty"
          "gitbutler"
          "insomnia"
          "jetbrains-toolbox"
          "moonlight"
          "msty"
          "obs"
          "orbstack"
          "proton-mail"
          "raycast"
          "rectangle"
          "tabby"
          "teamviewer"
          "visual-studio-code"
        ];

        masApps = {
          Bitwarden = 1352778147;
          GarageBand = 682658836;
          "GIPHY CAPTURE" = 668208984;
          iMovie = 408981434;
          Keynote = 409183694;
          Numbers = 409203825;
          Pages = 409201541;
          Tailscale = 1475387142;
        };

        onActivation = {
          cleanup = "none";
          autoUpdate = false;
          upgrade = false;
          extraEnv.HOMEBREW_NO_ANALYTICS = "1";
        };
      };
    };
}
