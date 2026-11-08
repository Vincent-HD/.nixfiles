{ ... }:
{
  # NixOS side: PipeWire audio
  config.flake.modules.nixos.sound =
    { pkgs, ... }:
    {
      services.pulseaudio.enable = false;
      security.rtkit = {
        enable = true;
        # RTKit caps its UID at three processes, but rootful Docker containers
        # share host UIDs: dockurr/windows runs wsddn as UID 995, NixOS's rtkit
        # UID. The watchdog thread then fails and portal D-Bus calls time out.
        args = [ "--no-limit-resources" ];
      };

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber.enable = true;
        pulse.enable = true;
        # jack.enable = true;

        # Dedicated comms sink that forwards into the current default sink.
        configPackages = [
          (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/20-communication-sink.conf" ''
            context.modules = [
              {
                name = libpipewire-module-loopback
                args = {
                  node.name = "communication_sink"
                  node.description = "Communication sink"

                  capture.props = {
                    node.name = "communication_sink.capture"
                    media.class = "Audio/Sink"
                    audio.channels = 2
                    audio.position = [ FL FR ]
                  }

                  playback.props = {
                    node.name = "communication_sink.playback"
                    target.object = "@DEFAULT_SINK@"
                    node.passive = true
                    stream.dont-remix = true
                    audio.channels = 2
                    audio.position = [ FL FR ]
                  }
                }
              }
            ]
          '')
        ];
      };
    };
}
