{ ... }:
{
  # NixOS: LocalSend discovers peers and transfers files over its default TCP/UDP port.
  config.flake.modules.nixos.localSend =
    { ... }:
    {
      networking.firewall.allowedTCPPorts = [ 53317 ];
      networking.firewall.allowedUDPPorts = [ 53317 ];
    };

  # Home Manager: install LocalSend's wrapped upstream release for the logged-in user.
  config.flake.modules.homeManager.localSend =
    { pkgs, ... }:
    {
      # macOS uses the existing Home Manager copyApps target for .app bundles.
      home.packages = [ (pkgs.callPackage ../packages/localsend { }) ];
    };
}
