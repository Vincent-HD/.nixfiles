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
            # Repeat a side action to cycle 1/2 -> 2/3 -> 1/3 instead of moving to
            # the next display, matching niri's `switch-preset-column-width`.
            subsequentExecutionMode = 0;
            # niri muscle memory on the Mac uses Ctrl+Option as the "Mod" chord,
            # because Command would make these global hotkeys swallow the standard
            # Cmd+H/M/T/R/F/Q/W application shortcuts. modifierFlags is NSEvent
            # bits: 786432 is Control (262144) plus Option (524288), and 917504
            # adds Shift. Key codes are ANSI: F is 3, M is 46, and the arrows are
            # left 123, right 124, down 125, up 126.
            maximize.keyCode = 3;
            maximize.modifierFlags = 786432;
            almostMaximize.keyCode = 46;
            almostMaximize.modifierFlags = 786432;
            leftHalf.keyCode = 123;
            leftHalf.modifierFlags = 786432;
            rightHalf.keyCode = 124;
            rightHalf.modifierFlags = 786432;
            topHalf.keyCode = 126;
            topHalf.modifierFlags = 786432;
            bottomHalf.keyCode = 125;
            bottomHalf.modifierFlags = 786432;
            previousDisplay.keyCode = 123;
            previousDisplay.modifierFlags = 917504;
            nextDisplay.keyCode = 124;
            nextDisplay.modifierFlags = 917504;
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
