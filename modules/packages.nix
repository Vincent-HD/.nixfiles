{
  config.perSystem =
    { pkgs, lib, ... }:
    {
      packages = {
        jj-ryu = pkgs.callPackage ../packages/jj-ryu { };
        lightjj = pkgs.callPackage ../packages/lightjj { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        crosspipe = pkgs.callPackage ../packages/crosspipe { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        sunshine-darwin = pkgs.callPackage ../packages/sunshine-darwin { };
      };
    };
}
