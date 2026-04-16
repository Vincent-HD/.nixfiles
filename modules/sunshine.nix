{ ... }:
{
  # Home Manager side: Sunshine
  config.flake.modules.nixos.sunshine =
    { pkgs, ... }:
    {
      services.sunshine = {
        enable = true;
        openFirewall = true;
        package = pkgs.sunshine.override { cudaSupport = true; };
      };
    };
}
