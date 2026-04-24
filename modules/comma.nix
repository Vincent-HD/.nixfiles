{ ... }:
{
  # NixOS side: install comma as a system package.
  config.flake.modules.nixos.comma =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.comma ];
    };
}
