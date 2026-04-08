{ inputs, config, ... }:
{
  # NixOS: Niri compositor, portals, greetd session (matches references/neoelectron-nixfiles).
  config.flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      imports = [
        inputs.niri.nixosModules.niri
      ];

      nixpkgs.overlays = [ inputs.niri.overlays.niri ];

      programs.niri.enable = true;

      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      xdg.portal.config.niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Access" = [ "gtk" ];
        "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };

      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "niri-session";
            user = config.flake.username;
          };
        };
      };

      services.greetd.restart = true;
    };

  # Home Manager: niri config, kitty (Mod+T), spawn noctalia-shell at startup.
  config.flake.modules.homeManager.niri =
    { pkgs, lib, ... }:
    {
      programs.kitty = {
        enable = true;
        settings = {
          font_size = lib.mkDefault 12;
          enable_audio_bell = lib.mkDefault false;
          confirm_os_window_close = lib.mkDefault 0;
          window_padding_width = lib.mkDefault 4;
        };
      };

      programs.niri.settings = {
        window-rules = [
          {
            matches = [
              { title = "^Picture in Picture$"; }
            ];
            open-floating = true;
          }
          {
            matches = [
              {
                app-id = "firefox$";
                title = "^Picture-in-Picture$";
              }
            ];
            open-floating = true;
          }
          # Brave extension pop-outs (e.g. Bitwarden) use app-id brave-<extension-id>-Default,
          # not brave-browser.
          {
            matches = [
              { app-id = "^brave-.+-Default$"; }
            ];
            open-floating = true;
          }
        ];

        # Must stay in sync with home.pointerCursor in modules/cursor-pointer.nix (see references/neoelectron-nixfiles).
        cursor = {
          theme = lib.mkDefault "Adwaita";
          size = lib.mkDefault 24;
        };

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        # Niri defaults to each monitor's EDID "preferred" mode, which is often 60 Hz even when
        # the panel supports 144/165 Hz. Plasma may have been using the high-refresh modes instead.
        # Refresh values must match `niri msg outputs` exactly (see Available modes).
        # Match by connector so renaming in niri msg is stable.
        outputs = {
          "DP-2" = {
            mode = {
              width = 3440;
              height = 1440;
              refresh = 164.900;
            };
            position = {
              x = 0;
              y = 0;
            };
          };
          "DP-3" = {
            mode = {
              width = 2560;
              height = 1440;
              refresh = 143.856;
            };
            position = {
              x = 3440;
              y = 0;
            };
          };
        };

        spawn-at-startup = [
          { command = [ "noctalia-shell" ]; }
        ];

        environment = {
          "NIXOS_OZONE_WL" = "1";
        };

        input = {
          keyboard.xkb = {
            layout = lib.mkDefault "fr";
            variant = lib.mkDefault "azerty";
          };
          focus-follows-mouse.enable = lib.mkDefault false;
          warp-mouse-to-focus.enable = lib.mkDefault false;
        };

        layout = {
          gaps = lib.mkDefault 8;
          center-focused-column = lib.mkDefault "on-overflow";

          border = {
            enable = lib.mkDefault true;
            width = lib.mkDefault 2;
            active.color = lib.mkDefault "#89b4fa";
            inactive.color = lib.mkDefault "#313244";
          };

          focus-ring.enable = lib.mkDefault false;

          preset-column-widths = [
            { proportion = 1.0 / 3.0; }
            { proportion = 1.0 / 2.0; }
            { proportion = 2.0 / 3.0; }
          ];

          default-column-width = {
            proportion = lib.mkDefault (1.0 / 2.0);
          };
        };

        binds = {
          "Mod+T".action.spawn = "kitty";
          "Mod+Space".action.spawn = [
            "noctalia-shell"
            "ipc"
            "call"
            "launcher"
            "toggle"
          ];

          "Mod+Q".action.close-window = [ ];

          "Mod+Left".action.focus-column-left = [ ];
          "Mod+Right".action.focus-column-right = [ ];
          "Mod+Up".action.focus-window-up = [ ];
          "Mod+Down".action.focus-window-down = [ ];

          "Mod+Shift+Left".action.move-column-left = [ ];
          "Mod+Shift+Right".action.move-column-right = [ ];
          "Mod+Shift+Up".action.move-window-up = [ ];
          "Mod+Shift+Down".action.move-window-down = [ ];

          "Mod+1".action.focus-workspace = 1;
          "Mod+2".action.focus-workspace = 2;
          "Mod+3".action.focus-workspace = 3;
          "Mod+4".action.focus-workspace = 4;
          "Mod+5".action.focus-workspace = 5;

          "Mod+Shift+1".action.move-window-to-workspace = 1;
          "Mod+Shift+2".action.move-window-to-workspace = 2;
          "Mod+Shift+3".action.move-window-to-workspace = 3;
          "Mod+Shift+4".action.move-window-to-workspace = 4;
          "Mod+Shift+5".action.move-window-to-workspace = 5;

          "Mod+R".action.switch-preset-column-width = [ ];
          "Mod+F".action.maximize-column = [ ];
          "Mod+Shift+F".action.fullscreen-window = [ ];

          "Mod+Alt+F".action.toggle-window-floating = [ ];
          "Mod+Alt+Shift+F".action.switch-focus-between-floating-and-tiling = [ ];

          "XF86AudioRaiseVolume".action.spawn = [
            "wpctl"
            "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "0.05+"
          ];
          "XF86AudioLowerVolume".action.spawn = [
            "wpctl"
            "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "0.05-"
          ];
          "XF86AudioMute".action.spawn = [
            "wpctl"
            "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle"
          ];

          "Print".action.screenshot = [ ];
          "Mod+Print".action.screenshot-screen = [ ];

          "Mod+Ctrl+Q".action.quit = { };
        };
      };
    };
}
