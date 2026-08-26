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
          # Keep only values that differ from the current DMS defaults. Theme
          # and other default-valued settings are intentionally left to DMS.
          dockTransparency = 0.85;
          firstDayOfWeek = 1;
          clockFormat = "HH:mm";
          cornerRadius = 7;
          barElevationEnabled = false;
          blurEnabled = true;

          showLauncherButton = false;
          showWeather = false;
          showMusic = false;
          showCpuTemp = false;
          showGpuTemp = false;
          showBattery = false;
          showWorkspaceApps = true;
          workspaceAppIconSizeOffset = 2;
          groupWorkspaceApps = false;
          workspaceActiveAppHighlightEnabled = true;
          spotlightSectionViewModes = {
            apps = "list";
          };
          dockSpacing = 8;
          dockIconSize = 48;

          # DMS uses a positive spacing value to float the bar away from the
          # screen edge, matching Noctalia's floating bar type.
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
                {
                  id = "workspaceSwitcher";
                  enabled = true;
                }
              ];
              centerWidgets = [ "focusedWindow" ];
              rightWidgets = [
                "dankActions:musicDucking"
                "dankActions:musicNormal"
                "cpuUsage"
                {
                  id = "cpuTemp";
                  enabled = true;
                  minimumWidth = true;
                }
                "memUsage"
                {
                  id = "diskUsage";
                  enabled = true;
                  mountPath = "/";
                  diskUsageMode = 3;
                  minimumWidth = true;
                }
                "network_speed_monitor"
                "clock"
                "systemTray"
                "clipboard"
                "notificationButton"
                "quickCapture"
              ];
              spacing = 8;
              innerPadding = 4;
              widgetPadding = 8;
              autoHide = false;
              openOnOverview = false;
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
          # entries preserve Noctalia's dynamic music/music-down icon while
          # exposing the same left/right click behavior.
          dankActions = {
            src = "${inputs.dms-plugins}/DankActions";
            settings = {
              variants = [
                {
                  id = "musicDucking";
                  name = "Music Ducking";
                  icon = "music_note";
                  clickCommand = ''if [ "$(easyeffects -a output 2>/dev/null)" = "Music Ducking" ]; then easyeffects -l "Without Music Ducking"; else easyeffects -l "Music Ducking"; fi'';
                  middleClickCommand = ''easyeffects -l "Without Music Ducking"'';
                  rightClickCommand = ''easyeffects -l "Without Music Ducking"'';
                  visibilityCommand = ''test "$(easyeffects -a output 2>/dev/null)" = "Music Ducking"'';
                  visibilityInterval = 1;
                  showIcon = true;
                  showText = false;
                }
                {
                  id = "musicNormal";
                  name = "Music (normal)";
                  icon = "music_off";
                  clickCommand = ''if [ "$(easyeffects -a output 2>/dev/null)" = "Music Ducking" ]; then easyeffects -l "Without Music Ducking"; else easyeffects -l "Music Ducking"; fi'';
                  middleClickCommand = ''easyeffects -l "Without Music Ducking"'';
                  rightClickCommand = ''easyeffects -l "Without Music Ducking"'';
                  visibilityCommand = ''test "$(easyeffects -a output 2>/dev/null)" != "Music Ducking"'';
                  visibilityInterval = 1;
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
