{ ... }:
{
  # Home Manager side: Sunshine
  config.flake.modules.nixos.sunshine =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.sunshine
      ];

      services.sunshine = {
        enable = true;
        openFirewall = true;
      };
    };
}
