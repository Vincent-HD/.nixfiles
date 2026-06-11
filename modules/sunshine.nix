{ ... }:
{
  # NixOS system service: Sunshine with NVIDIA CUDA support.
  config.flake.modules.nixos.sunshine =
    { pkgs, ... }:
    {
      services.sunshine = {
        enable = true;
        capSysAdmin = true;
        openFirewall = true;
        package = pkgs.sunshine.override { cudaSupport = true; };
      };
    };

  # Home Manager side: official signed Sunshine.app for Apple Silicon.
  config.flake.modules.homeManager.sunshine =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.callPackage ../packages/sunshine-darwin { })
      ];
    };
}
