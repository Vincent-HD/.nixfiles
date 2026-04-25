{ inputs, ... }:
{
  # NixOS: services Noctalia widgets expect (battery, power profiles).
  config.flake.modules.nixos.noctalia =
    { ... }:
    {
      services.power-profiles-daemon.enable = true;
      services.upower.enable = true;
    };

  # Home Manager: Noctalia shell (from upstream flake homeModules.default).
  config.flake.modules.homeManager.noctalia =
    { config, ... }:
    let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      programs.noctalia-shell.package = pkgs.noctalia-shell.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          ${pkgs.python3}/bin/python3 ${./patches/rewrite-notificationservice.py} "$out/share/noctalia-shell/Services/System/NotificationService.qml"
          cp ${./patches/NiriService.qml} "$out/share/noctalia-shell/Services/Compositor/NiriService.qml"
        '';
      });

      programs.noctalia-shell = {
        enable = true;
        settings = {
          settingsVersion = 59;

          bar = {
            barType = "floating";
            density = "comfortable";
            widgets = {
              left = [
                {
                  id = "ControlCenter";
                  useDistroLogo = true;
                }
                {
                  id = "Workspace";
                  labelMode = "none";
                  showApplications = true;
                }
              ];
              center = [
                {
                  id = "ActiveWindow";
                  maxWidth = 250;
                }
              ];
              right = [
                {
                  colorizeSystemIcon = "primary";
                  generalTooltipText = "Duck music when someone talks";
                  icon = "music-down";
                  id = "CustomButton";
                  leftClickExec = ''[ "$(easyeffects -a output)" = "Music Ducking" ] && easyeffects -l "Without Music Ducking" || easyeffects -l "Music Ducking"'';
                  leftClickUpdateText = true;
                  parseJson = true;
                  rightClickExec = ''easyeffects -l "Without Music Ducking"'';
                  rightClickUpdateText = true;
                  showExecTooltip = false;
                  showTextTooltip = false;
                  textCommand = ''if [ "$(easyeffects -a output)" = "Music Ducking" ]; then printf '{"icon":"music-up"}'; else printf '{"icon":"music-down"}'; fi'';
                  textIntervalMs = 600000;
                }
                {
                  id = "SystemMonitor";
                  compactMode = false;
                  showNetworkStats = true;
                }
                {
                  id = "Volume";
                }
                {
                  id = "Microphone";
                }
                {
                  id = "Network";
                }
                {
                  id = "Clock";
                  formatHorizontal = "HH:mm";
                  formatVertical = "HH mm";
                }
                {
                  drawerEnabled = false;
                  id = "Tray";
                }
              ];
            };
          };

          general = {
            avatarImage = "/home/${config.home.username}/.face";
            radiusRatio = 0.4;
            iRadiusRatio = 0.4;
            clockFormat = "ddd dd MMM HH:mm:ss ";
            lockScreenAnimations = true;
            enableLockScreenMediaControls = true;
            telemetryEnabled = true;
            passwordChars = true;
          };

          ui = {
            fontDefault = "Sans Serif";
            fontFixed = "monospace";
            boxBorderEnabled = true;
          };

          location.autoLocate = false;

          wallpaper = {
            enabled = false;
            directory = "/home/${config.home.username}/Pictures/Wallpapers";
          };

          colorSchemes = {
            predefinedScheme = "Gruvbox";
          };

          idle = {
            enabled = true;
            screenOffTimeout = 120;
            suspendCommand = "echo \"\" > /dev/null";
            resumeSuspendCommand = "echo \"\" > /dev/null";
          };
        };
      };
    };
}
