{ ... }:
{
  # NixOS side: PipeWire audio
  flake.modules.nixos.sound =
    { ... }:
    {
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber.enable = true;
        pulse.enable = true;
        # jack.enable = true;
      };
    };
}
