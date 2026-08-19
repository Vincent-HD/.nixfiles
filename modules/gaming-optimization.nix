{ inputs, ... }:
{
  config.flake.modules.nixos.gamingOptimization =
    { pkgs, ... }:
    {
      # Import only nix-gaming's sysctl module; its optional game and Wine packages remain unused.
      imports = [ inputs.nix-gaming.nixosModules.platformOptimizations ];

      # Use the pinned overlay so the CachyOS kernel package set is exposed without replacing the
      # repository's normal nixpkgs package set.
      nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];

      # Enable the four SteamOS platform sysctls provided by nix-gaming.
      programs.steam.platformOptimizations.enable = true;

      # Keep the stock kernel as the default generation and expose CachyOS as a boot-menu
      # specialization. The x86-64-v3 variant is compatible with this host's Zen 3 CPU and is
      # available from the release binary cache.
      specialisation.cachyos.configuration = {
        boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest-x86_64-v3";
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
