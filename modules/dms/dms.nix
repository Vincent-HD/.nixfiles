{ inputs, ... }:
let
  dmsShellPackage =
    pkgs:
    inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell.overrideAttrs (previousAttrs: {
      postInstall = (previousAttrs.postInstall or "") + ''
        chmod u+w "$out/share/quickshell/dms/Modules/Settings" \
          "$out/share/quickshell/dms/Modules/Settings/WidgetsTabSection.qml"
        patch -d "$out" -p0 < "${./assets/dms-plugin-settings-menu.patch}"
      '';
    });
in
{
  # NixOS: install the DMS integration and the services used by its session,
  # while leaving startup to the Home Manager user service below.
  config.flake.modules.nixos.dms =
    { pkgs, ... }:
    let
      # NVIDIA 595 exposes NVENC API 13.0; FFmpeg 9 requires 13.1.
      gpuScreenRecorderPackage = pkgs.gpu-screen-recorder.override {
        ffmpeg = pkgs.ffmpeg_8;
      };
      dmsPackage = dmsShellPackage pkgs;
    in
    {
      imports = [ inputs.dms.nixosModules.dank-material-shell ];

      programs.dank-material-shell = {
        enable = true;
        package = dmsPackage;
        systemd.enable = false;
      };

      # DMS patches adw-gtk3 copies with its live generated palette for GTK3.
      environment.systemPackages = [ pkgs.adw-gtk3 ];

      # Install the privileged KMS helper wrapper so video recording does not
      # fall back to an interactive Polkit authentication prompt.
      programs.gpu-screen-recorder = {
        enable = true;
        package = gpuScreenRecorderPackage;
      };

      services.power-profiles-daemon.enable = true;
      services.upower.enable = true;
    };

  # Home Manager: DMS shell, native clipboard history, annotated captures,
  # video capture, and the first-party action widget used for EasyEffects.
  config.flake.modules.homeManager.dms =
    { config, pkgs, ... }:
    let
      # Keep the user-visible executable on the same FFmpeg/NVENC-compatible
      # build as the NixOS KMS wrapper above.
      gpuScreenRecorderPackage = pkgs.gpu-screen-recorder.override {
        ffmpeg = pkgs.ffmpeg_8;
      };
      dmsPackage = dmsShellPackage pkgs;
    in
    {
      imports = [
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
        inputs.dankcalendar.homeModules.dank-calendar
        inputs.tokitoki.homeManagerModules.default
      ];

      home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.persist-dms
        pkgs.coreutils
        pkgs.curl
        pkgs.file
        pkgs.ffmpeg
        gpuScreenRecorderPackage
        pkgs.grim
        pkgs.img2pdf
        pkgs.imagemagick
        pkgs.pipewire
        pkgs.pulseaudio
        pkgs.satty
        pkgs.slurp
        pkgs.tesseract
        pkgs.wl-clipboard
        pkgs.zbar
      ];

      programs.tokitoki.enable = true;

      programs.dank-material-shell = {
        enable = true;
        package = dmsPackage;

        # Use the user service as the single DMS instance. The Niri includes and
        # generated binds stay disabled because this repository owns config.kdl.
        systemd.enable = true;
        niri = {
          enableKeybinds = false;
          enableSpawn = false;
          includes.enable = false;
        };

        # persist-dms owns this generated file. It contains only settings that
        # differ from the DMS SettingsSpec defaults; plugin settings stay below.
        settings = (builtins.fromJSON (builtins.readFile ./assets/generated-settings.json)) // {
          # DMS 1.6's calendar backend value selects DankCalendar's dcal IPC service.
          calendarBackend = "dankcal";
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

          # Declarative launcher for the local web-service registry beside the plugin.
          serviceHub = {
            src = ./plugins/service-hub;
            settings = {
              enabled = true;
            };
          };
        };
      };

      # Install dcal and keep its background daemon available to the DMS calendar backend.
      programs.dank-calendar = {
        enable = true;
        systemd.enable = true;
      };

      # Keep GTK3 and Qt applications on DMS's generated GTK palette.
      home.sessionVariables = {
        DMS_SCREENSHOT_EDITOR = "satty";
        QT_QPA_PLATFORMTHEME = "gtk3";
        QT_QPA_PLATFORMTHEME_QT6 = "gtk3";
      };
      systemd.user.services.dms.Service.Environment = [
        "DMS_SCREENSHOT_EDITOR=satty"
        "QT_QPA_PLATFORMTHEME=gtk3"
        "QT_QPA_PLATFORMTHEME_QT6=gtk3"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/run/wrappers/bin"
      ];
    };
}
