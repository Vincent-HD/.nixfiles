{ ... }:
{
  # NixOS side: NVIDIA GPU
  flake.modules.nixos.graphics =
    { ... }:
    {
      hardware.graphics.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true;
    };
}
