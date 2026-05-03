{ ... }:
{
  # NixOS side: NVIDIA GPU
  config.flake.modules.nixos.graphics =
    { pkgs, config, ... }:
    {
      # PR #427: Adds NVENC hardware encoding support via VA-API
      # https://github.com/elFarto/nvidia-vaapi-driver/pull/427
      nixpkgs.overlays = [
        (final: prev: {
          nvidia-vaapi-driver = prev.nvidia-vaapi-driver.overrideAttrs (oldAttrs: {
            version = "0.0.16-pr427";
            src = pkgs.fetchFromGitHub {
              owner = "elFarto";
              repo = "nvidia-vaapi-driver";
              rev = "3a58095f1833c997fd4f0a73ce3fa0300cdc20fc";
              sha256 = "sha256-Kz3ibI3XIpyOCQC7I+cD1N7qBvWwJITj9QdsTA0hsgQ=";
            };
          });
        })
      ];

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
