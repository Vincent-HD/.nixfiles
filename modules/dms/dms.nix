{ inputs, ... }:
{
  # NixOS: install the DMS integration and the services used by its session,
  # while leaving startup to the Home Manager user service below.
  config.flake.modules.nixos.dms =
    { ... }:
    {
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      programs.dank-material-shell = {
        enable = true;
        systemd.enable = false;
      };

      services.power-profiles-daemon.enable = true;
      services.upower.enable = true;
    };

  # Home Manager: DMS shell, native clipboard history, annotated captures,
  # video capture, and the first-party action widget used for EasyEffects.
  config.flake.modules.homeManager.dms =
    { config, pkgs, ... }:
    {
      imports = [
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
      ];

      home.packages = [
        pkgs.coreutils
        pkgs.curl
        pkgs.file
        pkgs.ffmpeg
        pkgs.gpu-screen-recorder
        pkgs.grim
        pkgs.img2pdf
        pkgs.imagemagick
        pkgs.jq
        pkgs.pipewire
        pkgs.pulseaudio
        pkgs.satty
        pkgs.slurp
        pkgs.tesseract
        pkgs.wl-clipboard
        pkgs.zbar
      ];

      programs.dank-material-shell = {
        enable = true;

        # Use the user service as the single DMS instance. The Niri includes and
        # generated binds stay disabled because this repository owns config.kdl.
        systemd.enable = true;
        niri = {
          enableKeybinds = false;
          enableSpawn = false;
          includes.enable = false;
        };

        settings = {
          # Keep only values that differ from the current DMS defaults. The
          # custom theme path is derived from Home Manager's home directory so
          # it does not hard-code the username.
          currentThemeName = "custom";
          currentThemeCategory = "registry";
          customThemeFile = "${config.home.homeDirectory}/.config/DankMaterialShell/themes/crimsonVoltage/theme.json";
          registryThemeVariants = {
            catppuccin = {
              dark = {
                flavor = "mocha";
                accent = "mauve";
              };
            };
            gruvboxMulti = {
              dark = {
                flavor = "material-hard-dark";
                accent = "blue";
              };
            };
          };

          blurEnabled = true;
          clockFormat = "HH:mm";
          cornerRadius = 8;
          niriLayoutBorderSize = 2;
          barElevationEnabled = false;

          showLauncherButton = false;
          showWeather = false;
          showMusic = false;
          showCpuTemp = false;
          showGpuTemp = false;
          showBattery = false;
          showWorkspacePadding = true;
          showWorkspaceApps = true;
          maxWorkspaceIcons = 6;
          workspaceAppIconSizeOffset = 2;
          groupWorkspaceApps = false;
          workspaceColorMode = "secondaryContainer";
          workspaceUnfocusedColorMode = "schh";
          workspaceFocusedBorderColor = "primaryContainer";
          controlCenterWidgets = [
            {
              id = "volumeSlider";
              enabled = true;
              width = 50;
            }
            {
              id = "inputVolumeSlider";
              enabled = true;
              width = 50;
            }
            {
              id = "wifi";
              enabled = true;
              width = 50;
            }
            {
              id = "idleInhibitor";
              enabled = true;
              width = 50;
            }
            {
              id = "bluetooth";
              enabled = true;
              width = 50;
            }
            {
              id = "audioOutput";
              enabled = true;
              width = 50;
            }
            {
              id = "audioInput";
              enabled = true;
              width = 50;
            }
            {
              id = "nightMode";
              enabled = true;
              width = 50;
            }
            {
              id = "darkMode";
              enabled = true;
              width = 50;
            }
            {
              id = "builtin_tailscale";
              enabled = true;
              width = 50;
            }
          ];

          # The widget layout is custom; omitted per-bar options use DMS's
          # current defaults.
          barConfigs = [
            {
              id = "default";
              name = "Main Bar";
              enabled = true;
              position = 0;
              screenPreferences = [ "all" ];
              showOnLastDisplay = true;
              leftWidgets = [
                "controlCenterButton"
                "workspaceSwitcher"
              ];
              centerWidgets = [ "focusedWindow" ];
              rightWidgets = [
                "dankActions:musicDucking"
                "dankActions:musicNormal"
                "cpuUsage"
                "memUsage"
                "network_speed_monitor"
                "clock"
                "systemTray"
                "clipboard"
                "notificationButton"
                "quickCapture"
              ];
              innerPadding = 4;
              widgetPadding = 8;
            }
          ];

          # Match Noctalia's current idle policy: blank the displays after five
          # minutes, but do not lock or suspend automatically.
          acMonitorTimeout = 300;
        };

        clipboardSettings = {
          disabled = false;
          disableHistory = false;
          maxHistory = 100;
          maxEntrySize = 10485760;
          autoClearDays = 0;
          clearAtStartup = false;
        };

        plugins = {
          # Quick Capture is the interactive screenshot/annotation workflow;
          # screenCaptureToolbar below remains available for video recording.
          quickCapture = {
            src = inputs.quick-capture;
            settings = {
              middleClickAction = "region";
              rightClickAction = "clipboard";
              menuRightClickAction = "copy";
              screenshotBackend = "dms";
              skipConfirm = true;
              includeCursor = false;
              defaultHideControlCenter = true;
              resetLastRegion = false;
              doneAction = "both";
              saveDirectory = "~/Pictures/Screenshots";
              saveFilenamePattern = "Screenshot-%Y-%m-%d_%H-%M-%S";
              outputFormat = "png";
              jpegQuality = 90;
              webpQuality = 90;
              scrollInterval = 500;
            };
          };

          screenCaptureToolbar = {
            src = inputs.screen-capture-toolbar;
            settings = {
              captureMode = "interactive";
              copyPathOnCapture = false;
              copyToClipboard = true;
              recordAudio = false;
              recordMic = false;
              saveToDisk = true;
              videoFormat = "mp4";
            };
          };

          # Dank Actions supports declarative variants. Two mutually exclusive
          # entries expose a dynamic hearing/hearing-disabled icon while
          # preserving the same left/right click behavior.
          # The 600-second polling interval handles external changes; resetting
          # both widgets after an action refreshes their visibility immediately.
          dankActions = {
            src = "${inputs.dms-plugins}/DankActions";
            settings = {
              variants = [
                {
                  id = "musicDucking";
                  name = "Music Ducking";
                  icon = "hearing";
                  clickCommand = ''if [ "$(easyeffects -a output 2>/dev/null)" = "Music Ducking" ]; then easyeffects -l "Without Music Ducking"; else easyeffects -l "Music Ducking"; fi; dms ipc call widget reset dankActions:musicDucking >/dev/null 2>&1; dms ipc call widget reset dankActions:musicNormal >/dev/null 2>&1'';
                  middleClickCommand = ''easyeffects -l "Without Music Ducking"; dms ipc call widget reset dankActions:musicDucking >/dev/null 2>&1; dms ipc call widget reset dankActions:musicNormal >/dev/null 2>&1'';
                  rightClickCommand = ''easyeffects -l "Without Music Ducking"; dms ipc call widget reset dankActions:musicDucking >/dev/null 2>&1; dms ipc call widget reset dankActions:musicNormal >/dev/null 2>&1'';
                  visibilityCommand = ''test "$(easyeffects -a output 2>/dev/null)" = "Music Ducking"'';
                  # Seconds between visibility checks; 600 = 10 minutes.
                  visibilityInterval = 600;
                  showIcon = true;
                  showText = false;
                }
                {
                  id = "musicNormal";
                  name = "Music (normal)";
                  icon = "hearing_disabled";
                  clickCommand = ''if [ "$(easyeffects -a output 2>/dev/null)" = "Music Ducking" ]; then easyeffects -l "Without Music Ducking"; else easyeffects -l "Music Ducking"; fi; dms ipc call widget reset dankActions:musicDucking >/dev/null 2>&1; dms ipc call widget reset dankActions:musicNormal >/dev/null 2>&1'';
                  middleClickCommand = ''easyeffects -l "Without Music Ducking"; dms ipc call widget reset dankActions:musicDucking >/dev/null 2>&1; dms ipc call widget reset dankActions:musicNormal >/dev/null 2>&1'';
                  rightClickCommand = ''easyeffects -l "Without Music Ducking"; dms ipc call widget reset dankActions:musicDucking >/dev/null 2>&1; dms ipc call widget reset dankActions:musicNormal >/dev/null 2>&1'';
                  visibilityCommand = ''test "$(easyeffects -a output 2>/dev/null)" != "Music Ducking"'';
                  # Seconds between visibility checks; 600 = 10 minutes.
                  visibilityInterval = 600;
                  showIcon = true;
                  showText = false;
                }
              ];
            };
          };
        };
      };

      # Satty is the annotation editor for DMS/Niri screenshots. The same
      # variable is exported to Niri-spawned commands and the DMS user service.
      home.sessionVariables.DMS_SCREENSHOT_EDITOR = "satty";
      systemd.user.services.dms.Service.Environment = [
        "DMS_SCREENSHOT_EDITOR=satty"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
    };
}
