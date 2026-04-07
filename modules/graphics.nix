{ ... }:
{
  # NixOS side: NVIDIA GPU
  config.flake.modules.nixos.graphics =
    { ... }:
    {
      hardware.graphics.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true;
    };
}
