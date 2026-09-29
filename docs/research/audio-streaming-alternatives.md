# Android phone audio to Linux: alternative research

> Checked 2026-09-29. Scope: Android system playback sent to a Linux desktop, with macOS and Windows support where available. Sources are official project documentation, release pages, or source code.

## Short conclusion

**WiFi Audio Streaming (WFAS) is the closest direct replacement for this use case.** Its Android app explicitly captures internal playback on Android 10+, and its desktop app has client and server modes for Linux, Windows, and macOS. The latest Android and desktop release pages both mark **v1.2** as the latest release, published on 2026-08-21. This is a good candidate to test on `pc-fixe` before removing AudioRelay.

AudioRelay already supports the requested direction and lists Linux, macOS, and Windows desktop clients. SonoBus is useful for microphone or audio-interface collaboration, but its current Android source uses a normal `AudioRecord` input and does not implement Android playback capture.

## Comparison

| Project | Android phone playback | Desktop receiver support | Relevant caveats |
| --- | --- | --- | --- |
| [AudioRelay](https://audiorelay.net/) | The official [Android guide](https://audiorelay.net/docs/android/stream-audio-from-a-phone-to-a-pc-or-to-another-phone) says the **Apps** source sends phone playback to another device, requires Android 10+, and may fail for apps that disallow recording. | The official [downloads page](https://audiorelay.net/downloads) lists Windows, Linux, and macOS desktop builds; it shows desktop version **0.27.5** and lists Windows 10+. | The official [FAQ](https://audiorelay.net/docs/help/faq) says audio is sent only on the local network to connected devices. |
| [WiFi Audio Streaming / WFAS](https://github.com/marcomorosi06/WiFiAudioStreaming-Android) ([desktop](https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop)) | The Android README documents **Internal Audio** for apps, games, and music on Android 10+. It uses Android's temporary screen-capture consent flow; the source creates `MediaProjection` and an `AudioPlaybackCaptureConfiguration` for media, game, and unknown usage types ([capture service](https://github.com/marcomorosi06/WiFiAudioStreaming-Android/blob/master/app/src/main/java/com/cuscus/wifiaudiostreaming/AudioCaptureService.kt), [recording setup](https://github.com/marcomorosi06/WiFiAudioStreaming-Android/blob/master/app/src/main/java/com/cuscus/wifiaudiostreaming/NetworkManager.kt)). | The [desktop README](https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop#readme) documents server and client modes for Windows 10/11 x86_64, macOS 13+ x86_64/arm64, and Linux x86_64. | Most complete match for Android → Linux. It is open source under EUPL-1.2; the separate WFAS v2 protocol reference is MIT licensed. |
| [SonoBus](https://www.sonobus.net/) | **Not a system-playback replacement.** The current Android source opens `AudioRecord` with the default audio source and requires `RECORD_AUDIO` ([JUCE Android audio backend](https://github.com/sonosaurus/sonobus/blob/main/JUCE/modules/juce_audio_devices/native/juce_android_Audio.cpp)). It has no `MediaProjection`/`AudioPlaybackCaptureConfiguration` path. Android's official capture API requires those pieces to capture another app's playback ([Android capture guide](https://developer.android.com/media/platform/av-capture)). | SonoBus provides Android plus Linux, macOS, and Windows applications. | Its Android manifest's `allowAudioPlaybackCapture="true"` means other apps may capture audio produced by SonoBus; it does not make SonoBus capture other apps' audio ([manifest](https://github.com/sonosaurus/sonobus/blob/main/mobile/Builds/Android/app/src/main/AndroidManifest.xml)). |

## WFAS release and package facts

Both repositories identify **v1.2** as the latest release:

- [Android v1.2 release](https://github.com/marcomorosi06/WiFiAudioStreaming-Android/releases/tag/v1.2), with `wifi-audio-streaming-v1.2.apk`.
- [Desktop v1.2 release](https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/tag/v1.2), published 2026-08-21.

The desktop v1.2 assets include:

- Linux: x86_64 and arm64/aarch64 AppImage, `.deb`, `.rpm`, `.tar.gz`, and `.zip` variants.
- macOS: arm64 `.dmg`, `.tar.gz`, and `.zip` variants. The README also documents x86_64 support, but the v1.2 release assets checked here include only macOS arm64 packages.
- Windows: x86_64 `.tar.gz` and `.zip` variants. The build instructions expose a Windows MSI task, but the v1.2 release asset list does not include an MSI.

## WFAS protocol, discovery, and network caveats

- WFAS v2 carries raw 16-bit PCM over UDP. The [protocol specification](https://github.com/marcomorosi06/wfas-protocol) describes discovery as a periodic UDP multicast beacon on **239.255.0.1:9091**; the Android README documents the same group and port.
- Multicast discovery can be blocked by a router or firewall, while a VPN or multiple interfaces can send traffic over the wrong path. The app supports manual IP entry and network-interface selection, and the [desktop README](https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop#readme) documents firewall guidance.
- WFAS supports unicast for one receiver and multicast for multiple receivers. Discovery is unauthenticated and spoofable; the protocol specification says its `auth`/`enc` beacon fields are display hints only. Multicast has no per-client authentication.
- The app offers optional `Off`, `Ask`, or `Key` authorization. Key mode uses mutual HMAC-SHA256 authentication, and optional ChaCha20-Poly1305 encryption authenticates and seals audio packets. The project describes this as a lightweight protection layer for trusted LAN/P2P use, not a high-threat secure transport.
- v1.2 also documents USB transport, but its release notes say Android USB tethering generally does not come up on macOS because macOS lacks a built-in RNDIS driver.

## Recommendation for this nixfiles task

1. Test WFAS v1.2 Android + Linux x86_64 first. The Nix configuration now packages the desktop client and opens UDP 9091; install the Android APK separately.
2. Verify multicast discovery, manual-IP fallback, the phone's Android/OEM capture permissions, and apps that restrict playback capture. Audio streaming has not been runtime-tested as part of this change.
3. Keep SonoBus out of this particular setup unless the source is a microphone or audio interface rather than phone system playback.
