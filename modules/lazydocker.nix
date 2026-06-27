{ ... }:
{
  config.flake.modules.homeManager.lazydocker =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lazydocker ];
    };
}
