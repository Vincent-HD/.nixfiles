# Use an Android phone as a webcam and screen mirror

This setup uses **DroidCam** for the webcam and camera controls, and **Android Screen Mirror** (scrcpy) for screen mirroring. The virtual webcam remains **Android Phone Camera** at `/dev/video42`. **DroidCam (Stop)** closes the client and stops the webcam.

## Install the configuration

Apply the NixOS configuration and reboot once so the `v4l2loopback` kernel module and `video` group membership take effect:

```bash
sudo nixos-rebuild switch --flake ~/.nixfiles#pc-fixe
```

## Connect DroidCam

1. Install the current [DroidCam Webcam & OBS Camera Android app](https://play.google.com/store/apps/details?id=com.dev47apps.obsdroidcam), open it, and allow its camera permission. This client uses the current app, rather than DroidCam Classic.
2. Put the phone and Linux computer on the same network. Open **DroidCam** from the Linux app launcher.
3. Click the empty preview, or right-click and choose **Add → DroidCam**. Select your phone from **Refresh Device List**, or use **WiFi IP** and enter the IP and port shown on the phone (normally port 4747).
4. Keep audio disabled unless you need the phone microphone. Start with **File → Settings → Video** set to **1280×720**, **30 fps**.
5. Once the video starts, reopen your meeting app and select **Android Phone Camera**.

USB also works using ADB: enable USB debugging as described below, connect and authorize the phone, then refresh DroidCam's device list and select the phone.

## Camera controls

Enable **Pro** inside the Android app for remote camera controls. In the Linux client, choose **View → Controls** and select your phone source. The controls dock connects to the selected phone; available controls depend on what the phone exposes. Use the phone app's camera selector for front/rear and available lenses. See [DroidCam's controls documentation](https://www.droidcam.app/help/).

The client keeps its settings in `~/.config/droidcam-obs-client`; these remain editable and are preserved across Nix rebuilds. Close DroidCam or use **DroidCam (Stop)** when finished.

## Connect scrcpy for screen mirroring

On the Xiaomi, open **Settings → About phone** and tap the OS version repeatedly until Developer options are enabled. Then open **Additional settings → Developer options**, enable **USB debugging**, connect the phone over USB, unlock it, and accept the computer's debugging authorization prompt. Check **Always allow from this computer** if shown.

For a wireless ADB connection on recent Android versions, put both devices on the same Wi-Fi network. In **Developer options → Wireless debugging**, choose **Pair device with pairing code**, then run:

```bash
adb pair PHONE_IP:PAIRING_PORT
adb connect PHONE_IP:DEVICE_PORT
```

Use the pairing and device ports shown by Android. Pair once; later, reconnect with the device port if Android has dropped the connection.

## Mirror or share the phone screen

Search for **Android Screen Mirror** to open the phone screen in a normal desktop window. You can select that window when an app asks which screen or window to share. USB works directly; for Wi-Fi, connect with the ADB steps above first.

If the Xiaomi screen mirrors but mouse clicks or keyboard input do not work, enable **Developer options → USB debugging (Security settings)** as well as ordinary USB debugging, then reboot the phone and reopen the mirror. Xiaomi can block scrcpy's input injection until this additional permission is enabled. See the [official scrcpy prerequisites](https://github.com/Genymobile/scrcpy#prerequisites).

If the phone is not detected, run `adb devices` and accept the authorization prompt on the phone. Camera service logs are available with:

```bash
journalctl --user -u android-phone-camera.service -e
```
