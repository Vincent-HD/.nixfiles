{ ... }:
{
  # NixOS side: NVIDIA GPU
  config.flake.modules.nixos.graphics =
    { pkgs, config, ... }:
    {
      hardware.graphics.enable = true;
      hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true;

      # NVIDIA VA-API driver for hardware video decode in browsers/Electron apps
      # https://github.com/elFarto/nvidia-vaapi-driver
      environment = {
        systemPackages = [ pkgs.libva-utils ];
        variables = {
          LIBVA_DRIVER_NAME = "nvidia";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          NVD_BACKEND = "direct";
        };
      };
    };
}
