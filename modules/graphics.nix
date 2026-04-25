{ ... }:
{
  # NixOS side: NVIDIA GPU
  config.flake.modules.nixos.graphics =
    { pkgs, config, ... }:
    {
      # PR #407: Fixes AV1 hardware decoding in Chromium/Brave
      # https://github.com/elFarto/nvidia-vaapi-driver/pull/407
      nixpkgs.overlays = [
        (final: prev: {
          nvidia-vaapi-driver = prev.nvidia-vaapi-driver.overrideAttrs (oldAttrs: {
            version = "0.0.16-pr407";
            src = pkgs.fetchFromGitHub {
              owner = "kode54";
              repo = "nvidia-vaapi-driver";
              rev = "b78dc72524d01200b590aeb8807e0e402be3ce06";
              sha256 = "sha256-SFYyEYzE6sxwJSgA8/wPZHKhLLJm5vV4QzZvCwM9wU4=";
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
