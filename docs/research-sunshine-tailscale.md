# Tailscale path diagnostics and Linux Sunshine/Moonlight resolutions

Research date: 2026-08-22

## Conclusion

1. Tailscale exposes the active path directly. Use `tailscale status` or
   `tailscale ping`; do not infer the active path from `netcheck` alone.
2. Moonlight supports entering a custom stream resolution, and Sunshine can
   encode a stream at that requested size, including scaling the captured
   desktop. This is different from changing the Linux desktop's actual output
   mode.
3. Sunshine's Windows-style automatic display-mode configuration is not
   available on Linux. For a true virtual monitor, the most credible options
   are a dedicated wlroots compositor with a headless output, or a GPU-backed
   Xorg/EDID virtual display. VKMS and standalone Gamescope are useful building
   blocks, but are not turnkey Sunshine virtual-display solutions.

For this Niri host, the low-risk path is to use Moonlight's custom stream size
first. If the goal is for games and the desktop to believe they are running on
an actual 2560x1600/1920x1080 monitor, use a separate virtual output/session;
do not turn the existing Niri session into a nested streaming session.

## 1. Detecting direct, peer-relay, and DERP paths

### Human-readable status

Run this on either endpoint, while the other endpoint is active:

```bash
tailscale status
```

For an active peer, interpret the connection field as follows:

| Output | Meaning |
| --- | --- |
| `direct 203.0.113.4:41641` or `direct [IPv6]:41641` | Direct UDP/WireGuard path |
| `relay "par"` | DERP relay in the Paris region |
| `peer-relay ...` | Tailscale Peer Relay through another tailnet device |

The Tailscale CLI source makes the precedence explicit: a non-empty current
address means direct; otherwise a peer-relay address means peer relay; only
when both are absent does a DERP relay get printed. See the
[`status` formatter](https://github.com/tailscale/tailscale/blob/main/cmd/tailscale/cli/status.go)
and the [`PeerStatus` fields](https://github.com/tailscale/tailscale/blob/main/ipn/ipnstate/ipnstate.go).
The same meanings are documented in [Tailscale's connection-type reference](https://tailscale.com/docs/reference/connection-types).

### Per-peer diagnostic ping

```bash
# Show the initial route and allow NAT traversal to settle.
tailscale ping --c=10 --until-direct=false <moonlight-client>

# Keep watching the route until interrupted.
tailscale ping --c=0 --until-direct=false <moonlight-client>
```

The route is printed on every response:

```text
pong ... via 198.51.100.20:41641 in 18ms       # direct
pong ... via [2001:db8::20]:41641 in 17ms       # direct over IPv6
pong ... via DERP(par) in 42ms                  # DERP
pong ... via peer-relay(192.0.2.10:7777:vni:1) in 5ms
```

By default, `tailscale ping` stops after ten pings or as soon as a direct path
is established. `--until-direct=false` is therefore important when testing a
relay-only case. Tailscale's CLI implementation also notes that the first
packets may use DERP while NAT traversal attempts to establish a direct path.
See the [official CLI implementation](https://github.com/tailscale/tailscale/blob/main/cmd/tailscale/cli/ping.go)
and [DERP troubleshooting guide](https://tailscale.com/docs/reference/troubleshooting/network-configuration/derp-routing).

This is a Tailscale-layer diagnostic ping, not an ICMP ping through the host
network stack and not a Sunshine bandwidth test. It proves the path selected
for the peer relationship, but not that every application packet is healthy.
For a streaming test, run it against the actual Moonlight device while the
stream is active and also watch `tailscale status --active`.

### Machine-readable status

`tailscale status --json` is useful for scripts, but Tailscale warns that its
JSON format can change between releases:

```bash
tailscale status --json | jq -r '
  .Peer | to_entries[] | .value
  | select(.HostName == "vincents-macbook-pro")
  | {HostName, Active, CurAddr, PeerRelay, Relay, LastHandshake}
'
```

Use these fields in this order:

```text
CurAddr != ""                    direct
CurAddr == "" and PeerRelay != "" peer relay
CurAddr == "" and PeerRelay == "" and Relay != ""  DERP
```

Do not use `Relay != ""` by itself as a DERP test. In the live check for this
host, the Mac had a direct IPv6 `CurAddr` while its JSON also contained
`Relay: "par"`; the human status correctly printed `direct`. The `Relay` field
can therefore represent the available/selected DERP region even when the
current path is direct.

### `tailscale netcheck`: useful, but not proof

```bash
tailscale netcheck
```

`netcheck` reports whether UDP works, public IPv4/IPv6 reachability, NAT mapping
behavior, port mapping, and latency to DERP regions. `UDP: true` means direct
connections are possible, not that a particular peer is currently direct. The
[device-connectivity documentation](https://tailscale.com/docs/reference/device-connectivity)
describes these fields and their limits.

### Current live result

On 2026-08-22, this host reported:

- `vincents-macbook-pro`: `active; direct [IPv6]:41641`;
- five `tailscale ping --until-direct=false` replies: 14–15 ms, all direct;
- `netcheck`: UDP available, with Paris as the nearest DERP region.

That confirms the tested host-to-Mac path is direct. The Moonlight device should
still be tested separately if it is not the Mac.

## 2. What “custom resolution” means in Moonlight/Sunshine

There are two separate resolutions:

1. **Stream resolution**: the pixel dimensions of the encoded video sent to
   Moonlight.
2. **Display mode**: the resolution at which the Linux compositor and games
   render their desktop/output.

Moonlight supports the first one. Its Qt settings source has a Custom entry,
stores the chosen width and height, and validates each dimension from 256 to
8192 pixels. It also removes preset modes that exceed the client's decoder
pixel limit. This is a client-side limit, not a promise that every host GPU,
encoder, or application accepts every value. See the current
[Moonlight settings source](https://raw.githubusercontent.com/moonlight-stream/moonlight-qt/master/app/gui/SettingsView.qml)
and the [stream configuration API](https://github.com/moonlight-stream/moonlight-common-c/blob/master/src/Limelight.h).

Sunshine receives the requested width and height in the launch session. Its
video pipeline configures the encoder with the requested dimensions, and its
software conversion path scales the captured frame to that output while
preserving aspect ratio and padding when necessary. See
[Sunshine's RTSP session structure](https://github.com/LizardByte/Sunshine/blob/master/src/rtsp.h)
and [video pipeline](https://github.com/LizardByte/Sunshine/blob/master/src/video.cpp).

Therefore:

- `1920x1080` from a 4K desktop is a normal supported scaling case;
- an unusual size such as `2560x1600` can be requested as a stream size;
- a different aspect ratio can produce scaling and black padding rather than
  changing the desktop layout;
- the encoder, client decoder, bitrate, and application may still reject or
  perform poorly at extreme sizes.

Sunshine does **not** automatically change a Linux output to the requested
mode. The `dd_resolution_option` and related `dd_*` settings are explicitly
documented as Windows-only. On Linux, Sunshine's supported mechanism is to
use preparation commands and the variables `SUNSHINE_CLIENT_WIDTH`,
`SUNSHINE_CLIENT_HEIGHT`, and `SUNSHINE_CLIENT_FPS`; its examples show
compositor-specific commands for X11, KDE, GNOME, and wlroots. See the
[Linux resolution examples](https://github.com/LizardByte/Sunshine/blob/master/docs/app_examples.md)
and the [`dd_*` configuration notes](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md).

The Moonlight “Optimize game settings for streaming” flag matters for
Sunshine's automatic display-preparation path. If a Linux preparation command
is used, it must still be able to configure the selected compositor/output;
Moonlight's custom stream size alone cannot create a missing Linux display
mode.

## 3. Linux alternatives for a true custom/virtual display

### A. Keep Niri and only customize the stream — best first test

Use Moonlight's Custom resolution and leave the physical Niri outputs alone.
Sunshine captures the current desktop and scales it to the requested stream
size. This is the simplest option and avoids a second session, portal routing,
keyring ownership, and nested-compositor problems.

It does not make games see a different monitor. A game that sizes itself from
the host display may still render at the physical mode and then be scaled by
Sunshine.

### B. Configure a physical Niri output temporarily

Current Niri documentation supports selecting a mode for a named output and,
since 25.11, declaring a custom mode/modeline. Niri warns that an out-of-spec
custom mode may damage a display. This can be paired with Sunshine's Linux
preparation commands, but it changes the real monitor and is not a virtual
display. See [Niri output configuration](https://github.com/niri-wm/niri/wiki/Configuration%3A-Outputs).

Niri does not currently document a headless-output mechanism. Its upstream
[headless-output discussion](https://github.com/niri-wm/niri/discussions/714)
was answered “not at the moment”, and the later virtual-output discussion is
still a design/proposal conversation. This is why creating a nested Niri
instance is not a clean substitute for a virtual monitor.

### C. Dedicated wlroots compositor with a headless output — most promising Wayland route

Sunshine's Linux documentation explicitly says its `wlr` capture method can
capture virtual displays in compositors such as Hyprland. wlroots has a
headless backend; `WLR_HEADLESS_OUTPUTS` controls the number of outputs, and
the backend creates them initially at 1280x720. A compositor can then expose
or configure a custom output mode. Sway's official output interface supports
`mode --custom` and runtime `swaymsg` changes. Sources:

- [Sunshine capture methods](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md);
- [wlroots environment variables/backend](https://github.com/swaywm/wlroots/blob/master/docs/env_vars.md)
  and [headless backend source](https://github.com/swaywm/wlroots/blob/master/backend/backend.c);
- [Sway output documentation](https://github.com/swaywm/sway/blob/master/sway/sway-output.5.scd).

This can provide a real GPU-composited Wayland output for a separate streaming
session, with Sunshine set to `capture = wlr`. It is substantially cleaner
than putting a second compositor inside the existing Niri desktop, but it is
still a separate session: portals, agents, D-Bus services, and application
state must be deliberately made available there. NVIDIA support and the exact
capture/encoder combination would need a runtime test.

### D. DRM virtual outputs and VKMS — possible, but experimental

The Linux kernel's VKMS is a software-only KMS driver intended for testing and
running X or similar software on headless machines. It can create multiple
instances through configfs, but the current kernel documentation lists live
output mode changes and refresh-rate changes as future work. See the
[kernel VKMS documentation](https://docs.kernel.org/gpu/vkms.html).

That makes VKMS useful for experimentation, not a dependable exact-resolution
Sunshine display on this NVIDIA desktop. Sunshine's tracker also contains a
VKMS virtual-monitor report with black-screen/GL failures, so it should not be
treated as a supported path; see [Sunshine issue #2044](https://github.com/LizardByte/Sunshine/issues/2044).

A different DRM approach is forcing an unused GPU connector on with a custom
EDID, or using a physical HDMI/DP dummy plug whose EDID advertises the desired
modes. Sunshine's own Linux/NVIDIA guide documents an accelerated Xorg
TwinView virtual display, and its current issue tracker describes EDID-forced
connectors as a working but out-of-tree workaround. The trade-offs are
connector/GPU-specific behavior, reboot requirements for some EDID changes,
and possible loss of HDR/VRR on a forced connector. See the
[official Xorg/NVIDIA headless guide](https://docs.lizardbyte.dev/projects/sunshine/v0.22.1/about/guides/linux/headless_ssh.html)
and [Sunshine's current virtual-display issue](https://github.com/LizardByte/Sunshine/issues/5266).

For an NVIDIA host where games must see a genuine accelerated display, this is
more promising than VKMS. A real dummy plug is usually the least surprising
version; a software/EDID connector is more flexible but more driver-specific.

### E. Xorg dummy or Xvfb

`Xvfb` can create an arbitrary virtual framebuffer with
`-screen <n> <width>x<height>x<depth>` and no physical display hardware. The official Xorg
manual describes it as a virtual-memory framebuffer, so it is appropriate for
GUI automation or a lightweight remote desktop, not a GPU-accelerated gaming
display. See the [Xvfb manual](https://www.x.org/archive/X11R7.0/doc/html/Xvfb.1.html).

The Xorg `xf86-video-dummy` driver is the analogous dummy Xorg-screen route.
It is separate from the current Wayland/Niri session. Sunshine documents X11
capture as the slowest and most CPU-intensive Linux capture method, so an
Xorg-dummy/Xvfb setup is a fallback for compatibility rather than the preferred
Sunshine gaming path. The NVIDIA TwinView guide above is preferable when an
accelerated Xorg virtual display is acceptable.

### F. Gamescope

Gamescope has independent `--nested-width/--nested-height` and
`--output-width/--output-height` controls, can expose Wayland clients, and has
a headless backend. Its own source describes that headless backend as having
no window and no DRM output. See the [Gamescope command-line source](https://github.com/ValveSoftware/gamescope/blob/master/src/main.cpp).

Gamescope is therefore useful for:

- running one game or a dedicated Steam session at a controlled internal size;
- scaling a game from one size to another;
- providing a compositor layer inside a separately managed streaming session.

It is not, by itself, a Sunshine virtual monitor. Running Gamescope as a
window inside Niri makes Sunshine capture that window as part of the existing
desktop; running it headless removes the DRM output Sunshine would normally
capture. It needs to be combined with a capture-compatible compositor/output
or a dedicated session.

## Recommended direction for this machine

1. Try Moonlight Custom at the desired stream size while keeping the current
   Sunshine/Niri session unchanged.
2. If the issue is that games must render natively at that size, choose either
   a dummy/EDID-backed accelerated output or a separate wlroots compositor with
   `wlr` capture.
3. Treat VKMS, Xvfb, and standalone headless Gamescope as experiments or
   compatibility tools, not the first production solution.
4. Continue using Tailscale. The tested peer is direct; if the actual
   Moonlight device shows `via DERP(...)` or `relay "..."`, investigate UDP/NAT
   traversal before opening Sunshine ports publicly.

No Nix configuration was changed as part of this research.

## 4. NanoKVM Pro as the HDMI sink

The repository identifies `HDMI-A-1` as `Philips Consumer Electronics Company
NanoKVM-Pro 0x0000003F` and selects `3440x1440@59.973` for it in
[`modules/niri.nix`](../modules/niri.nix). This is an EDID-backed virtual
display presented by the NanoKVM Pro's HDMI input, not a normal Philips panel.
The matching `3440x1440@60` mode is documented by Sipeed as one of the
NanoKVM Pro's built-in EDID modes. The identification of the exact stored EDID
from the repository comment is an inference; the repository does not contain
the binary EDID itself. See Sipeed's [NanoKVM Pro
introduction](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/introduction.html)
and [EDID mode table](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/extended.html).

### What the NanoKVM advertises

Sipeed documents the Pro as an HDMI capture device with HDMI loop-out. Its
published specifications list capture up to 4K45 and loop-out up to 4K; the
same page notes that the factory defaults use 4K30 plus 2K60 because some of the
higher modes are non-standard. The ATX guide separately describes 4K30 as the
maximum capture mode for that wiring path. The practical limit is therefore
firmware, capture-chip, and topology dependent rather than just the headline
HDMI bandwidth. See the [official specifications](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/introduction.html)
and [ATX wiring notes](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/atx_start.html).

The official EDID table includes these useful ultrawide modes:

- `3440x1440@60`;
- `3840x1600@50`;
- `2560x1080@75`.

It also includes `3840x2400@30` and common 16:10 modes. Sipeed explicitly
warns that modes not listed in the table may fail or show errors, and that some
lower modes can flicker. The changelog records later fixes for `3440x1440` and
support for the long modes, so firmware version matters too. See the
[built-in EDID table](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/extended.html)
and [NanoKVM Pro changelog](https://github.com/sipeed/NanoKVM-Pro/blob/main/CHANGELOG.md).

### Custom EDID and loop-out behavior

NanoKVM Pro supports modifying the EDID exposed by its virtual display. Sipeed
says that a monitor EDID can be cloned or a custom EDID can be written to expose
specific aspect ratios, refresh rates, or color characteristics. This changes
what the host GPU can enumerate; it does not expand the capture chip's ability
to decode an arbitrary HDMI timing.

There is an important loop-out caveat. When a loop-out display is connected,
the NanoKVM Pro's splitter combines the capture-chip EDID with the loop-out
display's EDID. Sipeed says that this combination is performed in hardware and
that the main control chip cannot fully control the resulting EDID. The actual
mode list may therefore differ from the EDID selected in the web interface.
With capture-only wiring, Sipeed documents a default maximum of 4K30; with a
loop-out display, the host receives the common mode list. Video adapters and
docking stations can change it again. See the [official video FAQ](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/faq.html)
and [EDID modification instructions](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM_Pro/extended.html).

The repository records the HDMI input connection but not whether the HDMI
loop-out is also connected. If loop-out is unused, a selected/custom EDID is
more likely to control the host directly. If loop-out is in use, its physical
display and the splitter's common-mode behavior must be included in every
resolution test.

### Effect on Niri and Sunshine

This makes NanoKVM Pro a more useful custom-resolution mechanism than a generic
dummy plug: the GPU already sees a real DRM output, and Niri can render the
desktop and games at a mode advertised by that output. The current
`3440x1440@59.973` entry is therefore a normal Niri mode selection, not a Niri
`custom-mode`. Niri requires a normal mode's refresh value to match the value
reported by `niri msg outputs`; `custom=true` is specifically for a mode the
output does not advertise, and Niri warns that unsupported custom modes may
fail or damage hardware. See Niri's [output configuration](https://github.com/niri-wm/niri/wiki/Configuration%3A-Outputs).

The safer sequence is:

1. Select or create a NanoKVM EDID containing a mode that its documented
   capture path supports.
2. Confirm that the host enumerates that mode on `HDMI-A-1`.
3. Let Niri select the enumerated mode normally.
4. Let Sunshine capture that actual Niri output; Moonlight's custom stream
   size can still scale it afterward if needed.

Sunshine's `global_prep_cmd` runs commands before and after all applications,
and its Linux preparation examples expose `SUNSHINE_CLIENT_WIDTH`,
`SUNSHINE_CLIENT_HEIGHT`, and `SUNSHINE_CLIENT_FPS`. In principle, a prep
script can select between modes that are already available to Niri. However,
rewriting the NanoKVM EDID for every Moonlight connection is not documented by
Sipeed as a live per-stream operation, and would require the host to re-read
the EDID and Niri to reconfigure the output. That is an inference from the
documented EDID and prep-command behavior, not a tested feature. It is also
especially fragile when loop-out EDID merging is active. See Sunshine's
[global preparation setting](https://github.com/LizardByte/Sunshine/blob/master/docs/configuration.md)
and [Linux resolution examples](https://github.com/LizardByte/Sunshine/blob/master/docs/app_examples.md).

**Result:** NanoKVM's editable EDID can provide a genuine Niri desktop mode for
supported resolutions, including the current `3440x1440` mode. It is promising
for a fixed custom streaming resolution, but it is not proof that arbitrary
Moonlight dimensions will work. Prefer a supported NanoKVM EDID plus normal
Niri mode selection; use `global_prep_cmd` only after that path is stable, and
treat per-client EDID rewriting or Niri custom modes as experiments.

No Nix or runtime configuration was changed as part of this NanoKVM research.
