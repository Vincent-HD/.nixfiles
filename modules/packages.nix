{
  config.perSystem =
    { pkgs, ... }:
    {
      packages.crosspipe = pkgs.callPackage ../packages/crosspipe { };
      packages.lightjj = pkgs.callPackage ../packages/lightjj { };
    };
}
