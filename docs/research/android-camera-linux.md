# Android phone camera to Linux: options

> Checked 2026-10-07. Scope: viewing or using an Android phone camera on Linux. Sources are official Android, app, and project documentation.

## Short conclusion

**For this Xiaomi, choose scrcpy plus `v4l2loopback` as the dependable route for using the phone inside Linux apps.** It works on Android 12+ and does not depend on Xiaomi exposing Android's optional USB Webcam mode. On NixOS, configure `v4l2loopback` declaratively, then select its video device in the target app. scrcpy can connect by USB or ADB over Wi-Fi.

Android's built-in USB Webcam mode is simpler if present: Android 14 QPR1+ can expose a standard UVC webcam, but the manufacturer must enable it. Since Xiaomi model and firmware vary, treat it as a quick check rather than the plan.

For a **wireless live view in a window**, IP Webcam is the simplest option: start its server on the phone and open the displayed address in a Linux browser on the same Wi-Fi. It says the stream works without internet access. For a **direct camera preview over USB** when native UVC is unavailable, scrcpy supports camera mirroring on Android 12+.

For **selecting the phone as a camera inside another Linux app**, prefer Android's USB Webcam mode or scrcpy's V4L2 output. IP Webcam provides a network stream URL; it does not by itself create a Linux camera device that every app can select.

## Comparison

| Option | Best for | Linux setup | Requirements and caveats |
| --- | --- | --- | --- |
| Android USB Webcam mode | A phone camera available to Linux camera apps | Connect by USB, select **Webcam** in Android's USB notification, then choose the phone as a camera in a V4L2-capable app. | Android documents support on Android 14 QPR1+; the phone manufacturer must implement it. Pixel's official guide confirms the USB steps and UVC compatibility. |
| [IP Webcam](https://play.google.com/store/apps/details?id=com.pas.webcam) | Wireless live view in a browser or VLC | Install the Android app, start its server, then open its displayed URL on Linux. | Both devices need the same Wi-Fi/LAN. The app lists local streaming without internet and optional Ivideon cloud broadcasting; keep the cloud option off for a LAN-only setup and do not port-forward the server. |
| [scrcpy](https://github.com/Genymobile/scrcpy) | Virtual webcam for Linux apps; direct preview is optional | Send camera output to a configured `v4l2loopback` device and select that device in the app. | Camera capture needs Android 12+ and USB debugging. It can use USB or ADB over Wi-Fi. No Android app or internet connection is needed. `scrcpy` is available in Nixpkgs. |
| [DroidCam](https://www.dev47apps.com/droidcam/linux/) | Virtual webcam for calls and capture apps, including over Wi-Fi | Connect the Linux client to the phone's IP and port; select the resulting V4L2 camera in the target app. | The official Linux client documents 64-bit binaries. Wi-Fi/LAN needs both devices on the same network; USB needs ADB and USB debugging. Its install steps use system driver installation, so this is more involved on NixOS than scrcpy with declarative module setup. |
| [VDO.Ninja](https://docs.vdo.ninja/getting-started/mobile-phone-camera-into-webcam) | Browser-based sharing or feeding OBS, including remote viewing | Open the phone's publish link and open the view link in a Linux browser or OBS. | Works across Linux, Windows, and macOS through WebRTC. It is useful for remote sharing, but involves the VDO.Ninja service and links rather than a strictly local camera endpoint. |

Iriun also lists a Linux webcam client, but its official download page specifies Ubuntu 22.04+ and only a beta RPM, so it is a less clear fit for this NixOS machine.

## Suggested first try

1. You can quickly check whether the phone exposes **Webcam** in its USB notification. If present, select it and choose the phone in the Linux app.
2. Otherwise, use scrcpy plus `v4l2loopback`. Configure the module and create `/dev/videoN` on NixOS, enable USB debugging on Android, and connect by USB or ADB over Wi-Fi. Replace `N` below with the loopback device number:

   ```bash
   nix run nixpkgs#scrcpy -- --video-source=camera --camera-facing=back --v4l2-sink=/dev/videoN --no-video-playback --no-audio
   ```

## Sources

- Android Open Source Project: [Use a device as a webcam](https://source.android.com/docs/core/camera/webcam)
- Google Pixel Camera Help: [Use your Pixel phone as a webcam](https://support.google.com/pixelcamera/answer/14274129?hl=en)
- IP Webcam listing: [Google Play](https://play.google.com/store/apps/details?id=com.pas.webcam)
- scrcpy: [project README](https://github.com/Genymobile/scrcpy), [camera support](https://github.com/Genymobile/scrcpy/blob/master/doc/camera.md), and [Linux V4L2 output](https://github.com/Genymobile/scrcpy/blob/master/doc/v4l2.md)
- DroidCam: [official Linux instructions](https://www.dev47apps.com/droidcam/linux/)
- DroidCam: [Wi-Fi/LAN connection instructions](https://www.dev47apps.com/droidcam/connect/)
- VDO.Ninja: [mobile phone camera to webcam](https://docs.vdo.ninja/getting-started/mobile-phone-camera-into-webcam)
- Iriun: [official downloads and Linux requirements](https://www.iriun.com/)
