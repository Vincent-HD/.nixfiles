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
        };
      };
    };
}
