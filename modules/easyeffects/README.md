# EasyEffects

Home Manager manages the user service, selected global preferences, and three
native preset exports in `assets/`:

- `Basic microphone chain`: RNNoise, high-pass filter, gate, compressor.
- `Music Ducking`: output compressor with an external sidechain.
- `Without Music Ducking`: the same output chain with compressor bypassed.

The microphone profile and `Music Ducking` load when the service starts. The Dux
button can still switch between the two output profiles during the session.
The USB input/output device selections are declared in `default.nix`. The external
sidechain selection, `communication_sink.capture`, is merged into writable
`compressorrc` before startup because EasyEffects omits it from preset exports.
The communication sink itself is provided by `modules/sound.nix`.

Before the first rebuild, quit the existing EasyEffects instance completely so
the new systemd service can take ownership. Home Manager backs up the existing
preset and autostart files using this host's `hm-backup` extension.

## Updating a profile

Adjust the effects in EasyEffects and save them under a new, temporary preset
name. Home Manager's installed profiles point into the read-only Nix store, so
they cannot be overwritten through the UI. Copy the new JSON export into the
corresponding `assets/` file, review the diff, and rebuild. Keep the managed preset
names stable so the Dux button continues to recognize them.

Only meaningful preferences are declared. Window geometry, usage counters, and
other transient state remain writable and local. The generated XDG autostart
entry is masked; the Home Manager systemd user service owns startup and restarts
EasyEffects after a failure.
