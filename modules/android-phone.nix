{ inputs, config, ... }:
let
  username = config.flake.username;
in
{
  # Expose DroidCam's video stream as a stable V4L2 webcam device.
  config.flake.modules.nixos.androidPhone =
    { config, ... }:
    {
      boot.kernelModules = [ "v4l2loopback" ];
      boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
      boot.extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=42 card_label="Android Phone Camera" exclusive_caps=1
      '';

      users.users.${username}.extraGroups = [ "video" ];
    };

  # Use DroidCam's controls for the webcam and scrcpy for Android screen mirroring.
  config.flake.modules.homeManager.androidPhone =
    { pkgs, ... }:
    let
      droidcam = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.droidcam-client;
      cameraService = "android-phone-camera.service";

      screenMirror = pkgs.writeShellApplication {
        name = "android-screen-mirror";
        runtimeInputs = [ pkgs.scrcpy ];
        text = ''
          exec scrcpy --window-title="Android Screen Mirror" "$@"
        '';
      };

      startCamera = pkgs.writeShellApplication {
        name = "android-phone-camera-start";
        runtimeInputs = [
          pkgs.libnotify
          pkgs.systemd
        ];
        text = ''
          systemctl --user reset-failed ${cameraService} || true
          if ! systemctl --user start ${cameraService}; then
            notify-send "DroidCam" "Could not open the client. Check: journalctl --user -u ${cameraService}" || true
            exit 1
          fi
        '';
      };

      stopCamera = pkgs.writeShellApplication {
        name = "android-phone-camera-stop";
        runtimeInputs = [
          pkgs.systemd
        ];
        text = ''
          systemctl --user stop ${cameraService}
        '';
      };
    in
    {
      home.packages = [
        pkgs.android-tools
        pkgs.scrcpy
        pkgs.v4l-utils
        droidcam
        screenMirror
        startCamera
        stopCamera
      ];

      xdg.desktopEntries.android-screen-mirror = {
        name = "Android Screen Mirror";
        genericName = "Mirror Android screen";
        comment = "Mirror and share the Android screen with scrcpy";
        exec = "${screenMirror}/bin/android-screen-mirror";
        icon = "phone";
        terminal = false;
        categories = [
          "AudioVideo"
          "Video"
        ];
      };

      xdg.desktopEntries."com.dev47apps.droidcam" = {
        name = "DroidCam";
        genericName = "Android phone webcam";
        comment = "Open the DroidCam webcam preview and camera controls";
        exec = "${startCamera}/bin/android-phone-camera-start";
        icon = "droidcam-client";
        terminal = false;
        categories = [
          "AudioVideo"
          "Video"
        ];
      };

      xdg.desktopEntries.android-phone-camera-stop = {
        name = "DroidCam (Stop)";
        comment = "Close DroidCam and stop the phone webcam";
        exec = "${stopCamera}/bin/android-phone-camera-stop";
        icon = "camera-web";
        terminal = false;
        categories = [
          "AudioVideo"
          "Video"
        ];
      };

      systemd.user.services.android-phone-camera = {
        Unit = {
          Description = "DroidCam phone webcam and controls";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = [
            "${droidcam}/bin/droidcam-client"
          ];
        };
      };
    };
}
