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

      # Use niri-unstable so config can use `include` and `recent-windows` (need niri ≥25.11; stable is 25.08).
      programs.niri.package = pkgs.niri-unstable;

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
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      audioCfg = config.custom.niri.audioBinds;
      mediaCfg = config.custom.niri.mediaBinds;
      niriExe = lib.getExe config.programs.niri.package;
      runNiriActions =
        actions: lib.concatStringsSep "\n" (map (action: "${niriExe} msg action ${action}") actions);
    in
    {
      options.custom.niri.audioBinds = {
        volumeUpKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for volume up.";
        };

        volumeDownKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for volume down.";
        };

        muteKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for mute toggle.";
        };

        volumeStep = lib.mkOption {
          type = lib.types.str;
          default = "0.05";
          description = "Volume step passed to wpctl, without the trailing + or -.";
        };
      };

      options.custom.niri.mediaBinds = {
        playPauseKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for play/pause.";
        };

        stopKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for stop.";
        };

        previousKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for previous track.";
        };

        nextKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "XKB key name used by niri for next track.";
        };
      };

      config = {
        home.packages = [ pkgs.playerctl ];

        programs.kitty = {
          enable = true;
          settings = {
            font_size = lib.mkDefault 12;
            enable_audio_bell = lib.mkDefault false;
            confirm_os_window_close = lib.mkDefault 0;
            window_padding_width = lib.mkDefault 4;
          };
        };

        # Not in niri-flake's programs.niri.settings schema yet; merged via `include` (requires niri-unstable).
        xdg.configFile."niri/recent-windows.kdl".text = ''
          recent-windows {
              debounce-ms 400
              binds {
                  Alt+Tab { next-window; }
                  Alt+Shift+Tab { previous-window; }
              }
          }
        '';

        # Let Home Manager own the final config directly instead of patching a managed file in-place.
        xdg.configFile.niri-config.enable = lib.mkForce false;
        xdg.configFile."niri/config.kdl" = {
          force = true;
          text = ''
            include "recent-windows.kdl"

            ${config.programs.niri.finalConfig}
          '';
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
                {
                  app-id = "^brave-.+";
                  title = "^Bitwarden$";
                }
              ];
              open-floating = true;
            }
            {
              matches = [
                {
                  app-id = "^steam$";
                  title = "^(Steam|Sign in to Steam|Settings|Properties|Friends List|Screenshot Uploader)"; # specific windows
                }
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
            # DP-3 = DELL Inc. AW3423DWF JW542S3, 3440x1440 @ 164.9 Hz primary.
            "DP-3" = {
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
            # DP-2 = HP Inc. HP 27xq CNK9182GLP, 2560x1440 @ 143.856 Hz.
            # Keep it directly next to the DELL so the KVM can stay 200 px beyond it.
            "DP-2" = {
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
            # HDMI-A-1 = Philips Consumer Electronics Company NanoKVM-Pro 0x0000003F,
            # 3440x1440 @ 59.973 Hz support display for remote access.
            # Keep it 200 px away from the HP.
            "HDMI-A-1" = {
              mode = {
                width = 3440;
                height = 1440;
                refresh = 59.973;
              };
              position = {
                x = 6200;
                y = 0;
              };
            };
          };

          spawn-at-startup = [
            { command = [ "noctalia-shell" ]; }
          ];

          environment = {
            # NixOS Chromium/Electron: prefer Ozone Wayland over XWayland. Niri applies this only to processes
            # it spawns; it does not propagate to systemd’s global env (see niri “Miscellaneous” → environment).
            "NIXOS_OZONE_WL" = "1";
          };

          input = {
            mouse = {
              accel-speed = lib.mkDefault 0;
              accel-profile = "flat";
            };

            keyboard.xkb = {
              layout = lib.mkDefault "fr";
              variant = lib.mkDefault "azerty";
            };
            # Windows-like hover focus, but never scroll the workspace just to satisfy pointer focus.
            focus-follows-mouse.enable = lib.mkDefault true;
            focus-follows-mouse.max-scroll-amount = lib.mkDefault "10%";
            warp-mouse-to-focus.enable = lib.mkDefault false;
          };

          gestures = {
            # Dragging a titlebar against the left/right screen edge should not scroll the workspace.
            dnd-edge-view-scroll.max-speed = 0;
            # Use Mod+Tab for overview instead of edge-triggered hot corners.
            hot-corners.enable = false;
          };

          layout = {
            gaps = lib.mkDefault 8;
            center-focused-column = lib.mkDefault "on-overflow";
            # If there is only one column, center it.
            always-center-single-column = true;

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

          binds = lib.mkMerge [
            {
              # Launchers and core actions.
              # Vicinae replaces the old Noctalia launcher on the same shortcut.
              "Mod+Space".action.spawn = [
                "vicinae"
                "toggle"
              ];
              "Mod+Tab".action.open-overview = [ ];
              "Mod+T".action.spawn = "kitty";
              "Mod+Q".action.close-window = [ ];

              # Focus movement on arrows.
              "Mod+Left".action.focus-column-left = [ ];
              "Mod+Right".action.focus-column-right = [ ];
              "Mod+Up".action.focus-window-or-workspace-up = [ ];
              "Mod+Down".action.focus-window-or-workspace-down = [ ];

              # Focus movement on home-row keys.
              "Mod+H".action.focus-column-left = [ ];
              "Mod+L".action.focus-column-right = [ ];
              "Mod+K".action.focus-window-or-workspace-up = [ ];
              "Mod+J".action.focus-window-or-workspace-down = [ ];

              # Vertical wheel moves through windows/workspaces.
              "Mod+WheelScrollUp" = {
                cooldown-ms = 150;
                action.focus-window-or-workspace-up = [ ];
              };
              "Mod+WheelScrollDown" = {
                cooldown-ms = 150;
                action.focus-window-or-workspace-down = [ ];
              };

              # Horizontal wheel moves horizontal focus.
              "Mod+WheelScrollLeft" = {
                cooldown-ms = 150;
                action.focus-column-left = [ ];
              };
              "Mod+WheelScrollRight" = {
                cooldown-ms = 150;
                action.focus-column-right = [ ];
              };

              # Move columns/windows on arrows.
              "Mod+Ctrl+Left".action.move-column-left = [ ];
              "Mod+Ctrl+Right".action.move-column-right = [ ];
              "Mod+Ctrl+Up".action.move-window-up-or-to-workspace-up = [ ];
              "Mod+Ctrl+Down".action.move-window-down-or-to-workspace-down = [ ];

              # Move columns/windows on home-row keys.
              "Mod+Ctrl+H".action.move-column-left = [ ];
              "Mod+Ctrl+L".action.move-column-right = [ ];
              "Mod+Ctrl+K".action.move-window-up = [ ];
              "Mod+Ctrl+J".action.move-window-down = [ ];

              # Move focused window to adjacent monitor.
              "Mod+Shift+Left".action.move-window-to-monitor-left = [ ];
              "Mod+Shift+Right".action.move-window-to-monitor-right = [ ];

              # Windows-style sizing / split helpers.
              "Mod+Alt+Left".action.spawn-sh = runNiriActions [
                "set-column-width 33.333%"
                "move-column-left"
              ];
              "Mod+Alt+Right".action.spawn-sh = runNiriActions [
                "set-column-width 33.333%"
                "move-column-right"
              ];
              "Mod+Alt+Up".action.consume-or-expel-window-right = [ ];
              "Mod+Alt+Down".action.consume-or-expel-window-left = [ ];

              # Overview navigation on the wheel.
              "Mod+Shift+WheelScrollUp" = {
                cooldown-ms = 150;
                action.spawn-sh = ''
                  ${niriExe} msg action open-overview
                  ${niriExe} msg action focus-window-up
                '';
              };
              "Mod+Shift+WheelScrollDown" = {
                cooldown-ms = 150;
                action.spawn-sh = runNiriActions [
                  "open-overview"
                  "focus-window-down"
                ];
              };

              # Workspaces by number.
              "Mod+1".action.focus-workspace = 1;
              "Mod+2".action.focus-workspace = 2;
              "Mod+3".action.focus-workspace = 3;
              "Mod+4".action.focus-workspace = 4;
              "Mod+5".action.focus-workspace = 5;

              # Workspaces by number on AZERTY top row.
              "Mod+ampersand".action.focus-workspace = 1;
              "Mod+eacute".action.focus-workspace = 2;
              "Mod+quotedbl".action.focus-workspace = 3;
              "Mod+apostrophe".action.focus-workspace = 4;
              "Mod+parenleft".action.focus-workspace = 5;

              # Move window to numbered workspace.
              "Mod+Shift+1".action.move-window-to-workspace = 1;
              "Mod+Shift+2".action.move-window-to-workspace = 2;
              "Mod+Shift+3".action.move-window-to-workspace = 3;
              "Mod+Shift+4".action.move-window-to-workspace = 4;
              "Mod+Shift+5".action.move-window-to-workspace = 5;

              # Move window to numbered workspace on AZERTY top row.
              "Mod+Shift+ampersand".action.move-window-to-workspace = 1;
              "Mod+Shift+eacute".action.move-window-to-workspace = 2;
              "Mod+Shift+quotedbl".action.move-window-to-workspace = 3;
              "Mod+Shift+apostrophe".action.move-window-to-workspace = 4;
              "Mod+Shift+parenleft".action.move-window-to-workspace = 5;

              # Window state and layout helpers.
              "Mod+R".action.switch-preset-column-width = [ ];
              "Mod+F".action.maximize-column = [ ];
              "Mod+Shift+F".action.fullscreen-window = [ ];
              "Mod+Alt+F".action.toggle-window-floating = [ ];
              "Mod+Alt+Shift+F".action.switch-focus-between-floating-and-tiling = [ ];

              # Screenshots and quit.
              "Print".action.screenshot = [ ];
              "Mod+Print".action.screenshot-screen = [ ];
              "Mod+Ctrl+Q".action.quit = { };
            }
            (lib.mkIf (audioCfg.volumeUpKey != null) {
              "${audioCfg.volumeUpKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "wpctl"
                  "set-volume"
                  "@DEFAULT_AUDIO_SINK@"
                  "${audioCfg.volumeStep}+"
                ];
              };
            })
            (lib.mkIf (audioCfg.volumeDownKey != null) {
              "${audioCfg.volumeDownKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "wpctl"
                  "set-volume"
                  "@DEFAULT_AUDIO_SINK@"
                  "${audioCfg.volumeStep}-"
                ];
              };
            })
            (lib.mkIf (audioCfg.muteKey != null) {
              "${audioCfg.muteKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "wpctl"
                  "set-mute"
                  "@DEFAULT_AUDIO_SINK@"
                  "toggle"
                ];
              };
            })
            (lib.mkIf (mediaCfg.playPauseKey != null) {
              "${mediaCfg.playPauseKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "playerctl"
                  "play-pause"
                ];
              };
            })
            (lib.mkIf (mediaCfg.stopKey != null) {
              "${mediaCfg.stopKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "playerctl"
                  "stop"
                ];
              };
            })
            (lib.mkIf (mediaCfg.previousKey != null) {
              "${mediaCfg.previousKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "playerctl"
                  "previous"
                ];
              };
            })
            (lib.mkIf (mediaCfg.nextKey != null) {
              "${mediaCfg.nextKey}" = {
                allow-when-locked = true;
                action.spawn = [
                  "playerctl"
                  "next"
                ];
              };
            })
          ];
        };
      };

    };
}
