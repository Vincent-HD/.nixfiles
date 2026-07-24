{ ... }:
{
  # NixOS: LocalSend discovers peers and transfers files over its default TCP/UDP port.
  config.flake.modules.nixos.localSend =
    { ... }:
    {
      networking.firewall.allowedTCPPorts = [ 53317 ];
      networking.firewall.allowedUDPPorts = [ 53317 ];
    };

  # Home Manager: install LocalSend's wrapped upstream AppImage for the logged-in user.
  config.flake.modules.homeManager.localSend =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage ../packages/localsend { }) ];
    };
}
