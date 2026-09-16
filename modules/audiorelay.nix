{ inputs, ... }:
{
  # NixOS: AudioRelay moves audio to and from the phone over UDP 59100, and needs
  # no capability, group, or extra device access beyond the user's own PipeWire
  # session.
  config.flake.modules.nixos.audioRelay =
    { pkgs, ... }:
    {
      networking.firewall.allowedUDPPorts = [ 59100 ];

      # Desktop-to-phone needs no device here: AudioRelay captures the monitor of
      # the real output, so the audio still plays on the PC. Only the
      # phone-as-microphone direction needs a device, named as upstream documents
      # it so the desktop app and the communications app find what the guide
      # tells the user to select:
      #   Virtual-Mic-Sink -> AudioRelay player outputs the phone mic here
      #   Virtual-Mic      -> comms apps pick this as an input device
      # ponytail: the mic direction needs the extra loopback because browsers and
      # Discord hide monitor sources from their input list. Drop it and point comms
      # apps at "Monitor of Virtual-Mic-Sink" if upstream ever ships that device.
      services.pipewire.configPackages = [
        (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/30-audiorelay.conf" ''
          context.objects = [
            { factory = adapter
              args = {
                factory.name = support.null-audio-sink
                node.name = "audiorelay_virtual_mic_sink"
                node.description = "Virtual-Mic-Sink"
                media.class = "Audio/Sink"
                monitor.channel-volumes = true
                monitor.passthrough = true
                object.linger = true
                audio.position = [ FL FR ]
              }
            }
          ]

          # Re-presents the monitor of Virtual-Mic-Sink as a plain source, which
          # is what upstream's `module-remap-source` recipe achieves on PulseAudio.
          context.modules = [
            {
              name = libpipewire-module-loopback
              args = {
                capture.props = {
                  node.name = "audiorelay_virtual_mic.capture"
                  target.object = "audiorelay_virtual_mic_sink"
                  stream.capture.sink = true
                  audio.position = [ FL FR ]
                }
                playback.props = {
                  node.name = "audiorelay_virtual_mic"
                  node.description = "Virtual-Mic"
                  media.class = "Audio/Source"
                  audio.position = [ FL FR ]
                }
              }
            }
          ]
        '')
      ];
    };

  # Home Manager: the Linux desktop application. macOS installs the vendor
  # application and its virtual audio devices through Homebrew instead; see the
  # darwin namespace below.
  config.flake.modules.homeManager.audioRelay =
    { pkgs, lib, ... }:
    let
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.audiorelay;
    in
    {
      # Gating happens on the option values, not on the returned attribute set:
      # forcing pkgs while the module arguments are still being resolved makes
      # Home Manager recurse.
      home.packages = lib.optionals isLinux [ package ];

      # The jpackage archive ships no desktop entry, so declare one for launchers.
      xdg.desktopEntries.audiorelay = lib.mkIf isLinux {
        name = "AudioRelay";
        genericName = "Audio streaming between devices";
        comment = "Use a phone as a speaker, microphone, or media source";
        exec = lib.getExe package;
        icon = "${package}/lib/AudioRelay.png";
        terminal = false;
        categories = [
          "AudioVideo"
          "Network"
        ];
      };
    };

  # nix-darwin: nixpkgs has no AudioRelay build, and the BlackHole driver needs
  # Xcode to compile, so Homebrew owns both. macOS gives applications no way to
  # capture system output, which makes one virtual audio device per direction
  # mandatory: BlackHole 2ch for output, BlackHole 16ch for the phone's mic.
  # The app is already permitted by the (MDM-managed) application firewall, so
  # `networking.applicationFirewall` must stay untouched here; the only prompts
  # are the macOS microphone and local-network consent dialogs.
  config.flake.modules.darwin.audioRelay =
    { ... }:
    {
      homebrew = {
        enable = true;
        casks = [
          "audiorelay"
          "blackhole-2ch"
          "blackhole-16ch"
        ];
      };
    };
}
