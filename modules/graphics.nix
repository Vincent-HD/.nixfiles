{ ... }:
{
  # NixOS side: NVIDIA GPU
  config.flake.modules.nixos.graphics =
    { pkgs, config, ... }:
    {
      # PR #430: Fixes Chrome stream format switches, including VP9 -> AV1 and SDR -> HDR.
      # https://github.com/elFarto/nvidia-vaapi-driver/pull/430
      nixpkgs.overlays = [
        (final: prev: {
          nvidia-vaapi-driver = prev.nvidia-vaapi-driver.overrideAttrs (oldAttrs: {
            version = "0.0.16-pr430";
            src = pkgs.fetchFromGitHub {
              owner = "imperishableSecret";
              repo = "nvidia-vaapi-driver";
              rev = "288a7ba79d47219ea6dea737ec8d684b53a8de36";
              sha256 = "sha256-wxgdf+Gln1Tv7S/EbVUNOpxJ4Z0Ew4VudBglX7d5XD8=";
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
