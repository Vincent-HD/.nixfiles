{ ... }:
{
  # NixOS system service: Sunshine with NVIDIA CUDA support.
  config.flake.modules.nixos.sunshine =
    { pkgs, ... }:
    {
      services.sunshine = {
        enable = true;
        capSysAdmin = true;
        # Keep Sunshine reachable through the private Tailscale interface only.
        openFirewall = false;
        package = pkgs.sunshine.override { cudaSupport = true; };
      };

      networking.firewall.interfaces.tailscale0 = {
        allowedTCPPorts = [
          47984
          47989
          47990
          48010
        ];
        allowedUDPPorts = [
          47998
          47999
          48000
          48002
          48010
        ];
      };
    };
}
