{ inputs, ... }:
{
  config.flake.modules.nixos.gamingOptimization =
    { pkgs, lib, ... }:
    {
      # Import only nix-gaming's sysctl module; its optional game and Wine packages remain unused.
      imports = [ inputs.nix-gaming.nixosModules.platformOptimizations ];

      # Use the pinned overlay so the CachyOS kernel package set is exposed without replacing the
      # repository's normal nixpkgs package set.
      nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];

      # Enable the four SteamOS platform sysctls provided by nix-gaming.
      programs.steam.platformOptimizations.enable = true;

      # Use the tested x86-64-v3 CachyOS kernel as the normal boot entry. It is compatible with
      # this host's Zen 3 CPU and is available from the release binary cache.
      boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest-x86_64-v3";

      # Keep an explicitly named stock-kernel entry in the same generation for rollback without
      # changing the rest of the gaming configuration.
      specialisation.stock.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
      };

      # nix-cachyos-kernel's release branch publishes its prebuilt kernels to this cache.
      nix.settings = {
        extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
        extra-trusted-public-keys = [
          "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        ];
      };
    };
}
