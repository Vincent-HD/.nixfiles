{ ... }:
{
  # NixOS: LocalSend discovers peers and transfers files over its default TCP/UDP port.
  config.flake.modules.nixos.localSend =
    { ... }:
    {
      networking.firewall.allowedTCPPorts = [ 53317 ];
      networking.firewall.allowedUDPPorts = [ 53317 ];
    };

  # Home Manager: install the cached native nixpkgs package to avoid the AppImage GTK runtime.
  config.flake.modules.homeManager.localSend =
    { pkgs, ... }:
    {
      # macOS uses the existing Home Manager copyApps target for .app bundles.
      home.packages = [ pkgs.localsend ];
    };
}
