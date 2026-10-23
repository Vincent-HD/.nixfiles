{ inputs, ... }:
let
  # Upstream now opens each plugin's settings directly from the widget row.
  dmsShellPackage = pkgs: inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
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

      # The pinned Sphinx hook reads a structured list as its first item only.
      # Keep both documentation builders for DMS's khal dependency.
      nixpkgs.overlays = [
        (_final: previous: {
          khal = previous.khal.overridePythonAttrs (_previousAttrs: {
            sphinxBuilders = "html man";
          });
        })
      ];

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
  # video capture, and the profile-aware EasyEffects widget.
  config.flake.modules.homeManager.dms =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Keep the user-visible executable on the same FFmpeg/NVENC-compatible
      # build as the NixOS KMS wrapper above.
      gpuScreenRecorderPackage = pkgs.gpu-screen-recorder.override {
        ffmpeg = pkgs.ffmpeg_8;
      };
      dmsPackage = dmsShellPackage pkgs;
      # Keep GitHub querying and alternate-token handling outside QML so the
      # token never appears in process arguments.
      githubPullRequestsCommand = pkgs.writeShellApplication {
        name = "dms-github-prs";
        runtimeInputs = [
          pkgs.gh
          pkgs.jq
        ];
        # Avoid pulling ShellCheck's large Haskell closure into a system rebuild.
        checkPhase = ''
          ${pkgs.bash}/bin/bash -n "$target"
        '';
        text = builtins.readFile ./plugins/github-pull-requests/dms-github-prs;
      };
    in
    {
      imports = [
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
        inputs.dankcalendar.homeModules.dank-calendar
      ];

      home.packages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.persist-dms
        githubPullRequestsCommand
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

          # A single widget changes its icon with the active EasyEffects profile.
          # Avoid visibility resets, which only reach one Dux widget instance.
          easyEffects = {
            src = ./plugins/easyeffects;
            settings = {
              executablePath = "${pkgs.easyeffects}/bin/easyeffects";
            };
          };

          # Declarative launcher for the local web-service registry beside the plugin.
          serviceHub = {
            src = ./plugins/service-hub;
            settings = {
              enabled = true;
              showBarLabel = false;
            };
          };

          # GitHub PRs uses the normal gh login for browsing and other authors,
          # plus an alternate token entered in the plugin settings for My PRs.
          githubPullRequests = {
            src = ./plugins/github-pull-requests;
            settings = {
              additionalAuthors = "";
              approvalToken = "";
              defaultRepository = "all";
              executablePath = "${githubPullRequestsCommand}/bin/dms-github-prs";
              refreshIntervalMinutes = "5";
              resultLimit = "50";
            };
          };
        };
      };

      # Merge defaults into the writable settings file without resetting values
      # entered in the GitHub widget, including its alternate approval token.
      xdg.configFile."dms/plugin_settings.json".enable = lib.mkForce false;
      home.activation.dmsPluginSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.jq
          ]
        } \
          ${pkgs.bash}/bin/bash ${./assets/merge-plugin-settings} \
          ${config.xdg.configFile."dms/plugin_settings.json".source} \
          "${config.xdg.configHome}/dms/plugin_settings.json" \
          "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json"
      '';

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
