# AudioRelay

AudioRelay streams audio between a desktop and an Android phone. This repository declares it on
both hosts: `nixos.audioRelay` plus `hm.audioRelay` on `pc-fixe`, and `darwin.audioRelay` on
`macbook-pro`. See `modules/audiorelay.nix`.

## Ports and permissions

AudioRelay uses **UDP 59100 only**. There is no TCP listener, and the port carries both the audio
stream and server discovery. Nothing else has to be opened, and on Linux the app needs no
capability, group, or device access beyond the user's own PipeWire session.

- **Linux**: `nixos.audioRelay` adds `59100` to `networking.firewall.allowedUDPPorts`.
- **macOS**: the application firewall needs no change. macOS prompts for **Microphone** access and
  for **Local Network** access on macOS 26+. Nix cannot pre-grant either, so accept both on first
  launch. `networking.applicationFirewall` is deliberately left unset: the MacBook Pro is
  MDM-managed and refuses `--setglobalstate`/`--add`.

Both directions share the port, so a phone can send and receive without further rules. Keep the
phone on the same subnet as the desktop; guest Wi-Fi and access-point client isolation both block
the connection. A VPN on either device must allow LAN traffic, which includes the Tailscale exit
node on `pc-fixe`.

## Linux (pc-fixe)

The app ships from `packages/audiorelay` as `.#audiorelay`. Upstream's documented method is a
`pactl` invocation that disappears on reboot and a hand edit of `/etc/pulse/default.pa`. Neither
is needed here: a PipeWire drop-in is configuration, so it survives reboots by construction.

Sending desktop audio to the phone needs no virtual device: pick
**`Monitor of <your output>`** in the AudioRelay server tab. PipeWire exposes the monitor of every
sink, so the PC keeps playing that audio while AudioRelay streams it. Upstream asks for a virtual
sink only when you want the PC to stay silent; for that, load `module-null-sink` per its guide and
select that sink's monitor instead.

Receiving the phone's microphone needs the two devices the drop-in creates:

| Device | Role |
| --- | --- |
| `Virtual-Mic-Sink` | AudioRelay's player outputs the phone microphone here |
| `Virtual-Mic` | communications applications pick this as an input device |

To use the phone as a microphone, pick the microphone source in the phone's server tab, pick
**`Virtual-Mic-Sink`** as the audio device in the desktop player tab, and select **`Virtual-Mic`** as
the input device in the communications application. Nothing plays on the PC speakers in this
direction: the phone audio lands in a sink so an application can treat it as a microphone, not so
that you can listen to it.

`Virtual-Mic` reproduces what upstream's PulseAudio recipe builds. That recipe uses
`module-remap-source` over the `Virtual-Mic-Sink` monitor, and PipeWire implements
`module-remap-source` as `libpipewire-module-loopback`, so the drop-in declares that module
directly with the same source and sink. The device exists because browsers and Discord hide monitor
sources from their input list, which makes `Monitor of Virtual-Mic-Sink` unselectable there.

## macOS (macbook-pro)

nixpkgs has no AudioRelay build, and `pkgs.blackhole` needs Xcode, so Homebrew owns both.
`darwin.audioRelay` declares three casks: `audiorelay`, `blackhole-2ch`, and
`blackhole-16ch`. Installing the BlackHole HAL drivers requires `sudo`.

The `audiorelay` cask selects the Apple silicon build on arm64 and both BlackHole drivers are
universal binaries. An install that predates the cask's arm64 variant keeps its Intel binary,
because Homebrew does not switch architectures while the version string is unchanged; macOS then
warns that the app will stop opening. `brew reinstall --cask audiorelay` swaps in the arm64
build.

macOS gives applications no way to capture system output, only microphones, so a virtual audio
device is mandatory in both directions, which is why upstream recommends installing both BlackHole
variants and using one per direction.

- **Mac to phone**: select `BlackHole 2ch` in the AudioRelay server tab, then in Audio MIDI Setup
  right-click `BlackHole 2ch` and choose *Use This Device For Sound Output*. To keep hearing the
  audio on the Mac as well, create a **Multi-Output device** in Audio MIDI Setup containing both
  `BlackHole 2ch` and the speakers, and use that as the sound output.
- **Phone as microphone**: select `BlackHole 16ch` as the output device in the AudioRelay player
  tab, then select `BlackHole 16ch` as the input device in the communications application.

Only the cask installs and the two consent prompts need the user. The Multi-Output device is Mac
state that no declarative layer manages, so create it once by hand.
