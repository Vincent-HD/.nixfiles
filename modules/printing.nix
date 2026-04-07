{ ... }:
{
  # NixOS side: CUPS printing service
  config.flake.modules.nixos.printing =
    { ... }:
    {
      services.printing.enable = true;
    };
}
