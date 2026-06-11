{ ... }:
{
  config.flake.modules.homeManager.btop =
    { pkgs, lib, ... }:
    let
      btopPackage = pkgs.btop.overrideAttrs (previousAttrs: {
        cmakeFlags =
          previousAttrs.cmakeFlags
          ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
            "-DBTOP_GPU=OFF"
          ];
      });
    in
    {
      programs.btop = {
        enable = true;
        package = btopPackage;
      };
    };
}
