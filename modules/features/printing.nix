{ ... }:
{
  # NixOS side: CUPS printing service
  flake.modules.nixos.printing =
    { ... }:
    {
      services.printing.enable = true;
    };
}
