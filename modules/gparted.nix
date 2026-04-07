{ ... }:
{
  # Polkit policy is in the gparted package; NixOS has no programs.gparted option (see mcp-nixos options search).
  config.flake.modules.nixos.gparted =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.gparted ];
    };
}
