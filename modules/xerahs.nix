{ ... }:
{
  config.flake.modules.homeManager.xerahs =
    { pkgs, ... }:
    {
      home.packages = [ (pkgs.callPackage ../packages/xerahs { }) ];
    };
}
