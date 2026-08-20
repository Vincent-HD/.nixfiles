{ ... }:
{
  config.flake.modules.nixos.tailscale =
    { ... }:
    {
      # Enable the Tailscale daemon and its direct-connection firewall port.
      services.tailscale = {
        enable = true;
        openFirewall = true;
        extraSetFlags = [ "--hostname=pc-fixe-nixos" ];
      };
    };
}
