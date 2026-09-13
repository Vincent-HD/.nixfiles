{ ... }:
{
  config.flake.modules.darwin.macosDefaults =
    { ... }:
    {
      system.defaults = {
        NSGlobalDomain.AppleInterfaceStyle = "Dark";

        dock = {
          autohide = true;
          tilesize = 64;
          wvous-br-corner = 14;
        };

        finder = {
          AppleShowAllFiles = true;
          FXPreferredViewStyle = "Nlsv";
          ShowPathbar = true;
          ShowStatusBar = false;
        };

        # Third-party GUI applications that keep their settings in the standard
        # per-user defaults domain. These are a seed, not an enforcement loop:
        # nix-darwin writes them at activation, and a change made inside the
        # application wins until the next activation. Quit the application before
        # switching, or it flushes its in-memory copy over the value on exit.
        CustomUserPreferences = {
          # Rectangle window manager. Modifier flags are NSEvent bits, so 786432
          # is Control (262144) plus Option (524288). Key codes are ANSI virtual
          # key codes: 11 is B and 45 is N. Sparkle keys such as `lastVersion` are
          # left to the application.
          "com.knollsoft.Rectangle" = {
            allowAnyShortcut = 1;
            alternateDefaultShortcuts = 1;
            footprintAnimationDurationMultiplier = 0;
            launchOnLogin = 1;
            subsequentExecutionMode = 1;
            reflowTodo = {
              keyCode = 45;
              modifierFlags = 786432;
            };
            toggleTodo = {
              keyCode = 11;
              modifierFlags = 786432;
            };
          };

          # AltTab. `preferencesVersion` is deliberately absent: AltTab uses it to
          # run its own settings migrations and rewrites it on every launch.
          "com.lwouis.alt-tab-macos" = {
            appearanceSize = 3;
            screensToShow = 0;
            spacesToShow = 0;
            updatePolicy = 1;
            windowMaxWidthInRow = 30;
          };

          # Scroll Reverser.
          "com.pilotmoon.scroll-reverser" = {
            InvertScrollingOn = 1;
            ReverseMouse = 0;
            ReverseX = 1;
            StartAtLogin = 1;
          };
        };
      };
    };
}
