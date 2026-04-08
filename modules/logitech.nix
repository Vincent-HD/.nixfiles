{ ... }:
{
  # Home Manager side: Logitech Unifying Receiver
  config.flake.modules.homeManager.logitech =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.sonaar
      ];
    };
}
