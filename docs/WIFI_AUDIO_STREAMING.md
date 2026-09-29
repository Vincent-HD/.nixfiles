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

1. Open **WiFi Audio Streaming** from the application launcher.
2. On Android, choose **Send (Server)**, enable **Internal Audio**, select **WFAS**, and choose
   **Unicast**.
3. Approve Android's capture prompt, then start the server.
4. On Linux, choose **Receive (Client)** and connect to the phone. The audio plays through the
   selected PipeWire output.

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
