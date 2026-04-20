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
    { lib, config, ... }:
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
          bar = {
            density = lib.mkDefault "comfortable";
            position = lib.mkDefault "left";
            widgets = {
              left = [
                {
                  id = "ControlCenter";
                  useDistroLogo = true;
                }
                {
                  id = "Network";
                }
              ];
              center = [
                {
                  id = "Workspace";
                  hideUnoccupied = false;
                  labelMode = "none";
                }
              ];
              right = [
                {
                  id = "Volume";
                }
                {
                  id = "Microphone";
                }
                {
                  id = "Clock";
                  formatHorizontal = "HH:mm";
                  formatVertical = "HH mm";
                  useMonospacedFont = true;
                  usePrimaryColor = true;
                }
                {
                  id = "Tray";
                }
              ];
            };
          };
          dock.enable = lib.mkDefault false;
          wallpaper.enabled = lib.mkDefault false;
          general = {
            avatarImage = "/home/${config.home.username}/.face";
            radiusRatio = lib.mkDefault 0.2;
          };
        };
      };
    };
}
