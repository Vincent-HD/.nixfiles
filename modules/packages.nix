{
  config.perSystem =
    { pkgs, ... }:
    {
      packages.crosspipe = pkgs.callPackage ../packages/crosspipe { };
    };
}
