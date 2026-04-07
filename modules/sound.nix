{ ... }:
{
  # NixOS side: PipeWire audio
  config.flake.modules.nixos.sound =
    { pkgs, ... }:
    {
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;

      # EasyEffects: PipeWire effects (noise gate, compressor, EQ, etc.) for mic and output.
      environment.systemPackages = [
        pkgs.easyeffects
      ];

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
