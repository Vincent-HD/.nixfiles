# WiFi Audio Streaming

WiFi Audio Streaming replaces AudioRelay on the Linux and macOS hosts. The Android app sends
phone playback to its desktop client over the local network. Desktop builds are also available for
Windows. This configuration packages x86_64 Linux and Apple Silicon macOS 13+; upstream also
provides a Windows 10/11 x86_64 build.

## Install the Android app

Install the latest APK from the [Android releases](https://github.com/marcomorosi06/WiFiAudioStreaming-Android/releases).
Internal playback capture requires Android 10 or newer. Android asks for screen-capture consent
when starting the stream; the app captures audio only. Some apps can block playback capture, as
described in the [Android audio capture documentation](https://developer.android.com/media/platform/av-capture).

## Receive on Linux

The `nixos.wifiAudioStreaming` module opens UDP 9091 for server-discovery beacons. The client
connects to the phone's advertised unicast stream port, so it does not need a fixed audio port.
Both devices need to be on the same local network; manual IP entry is available if multicast
discovery is filtered by the router.

Home Manager writes `~/.config/wfas/config.json` with auto-connect enabled for `192.168.1.20`
and `192.168.1.21`. It also adds a KDE/XDG autostart entry. At login the app starts in client mode,
tries each target every five seconds, retries ten seconds after a disconnect, and starts minimized
to the tray. The existing preferences to disable update checks and hide the visualizer are retained.

1. On Android, choose **Send (Server)**, enable **Internal Audio**, select **WFAS**, and choose
   **Unicast**.
2. Approve Android's capture prompt, then start the server.
3. On Linux, open **WiFi Audio Streaming** once from the application launcher and choose the
   desired output device. The app then retries the saved addresses automatically at login.

Unicast supports optional key-based authorization and ChaCha20-Poly1305 encryption. Configure the
same key on both ends if you want to enable them.

## macOS and Windows

Home Manager installs the macOS application bundle from the pinned Apple Silicon release archive.
Windows users can download the desktop archive from the [desktop releases](https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases).
When receiving phone audio on macOS, choose **Receive (Client)** and the desired output device; no
virtual audio device is needed for that direction.

## Update the desktop package

The Linux AppImage and macOS archive are pinned separately for their current platforms. Run the
registered update command on each target host when updating its artifact:

```bash
nix run .#update-pins -- --only wifi-audio-streaming
```
