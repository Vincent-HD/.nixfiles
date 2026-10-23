{ inputs, ... }:
{
  config.flake.modules.nixos.gamingOptimization =
    { pkgs, lib, ... }:
    {
      # Import only nix-gaming's sysctl module; its optional game and Wine packages remain unused.
      imports = [ inputs.nix-gaming.nixosModules.platformOptimizations ];

      # Use the pinned overlay so the CachyOS kernel package set is exposed without replacing the
      # repository's normal nixpkgs package set.
      nixpkgs.overlays = [
        inputs.nix-cachyos-kernel.overlays.pinned
        (_final: previous: {
          # The pinned CachyOS package set predates nixpkgs' module certificates.
          # Merge certificates only when the kernel supplies them; the stock
          # kernel retains its certificate checks for every external module.
          aggregateModules =
            modules:
            (previous.aggregateModules modules).overrideAttrs (previousAttrs: {
              postBuild =
                builtins.replaceStrings
                  [
                    "cp --no-preserve=mode,ownership --remove-destination"
                    "cat >> modules.cer"
                  ]
                  [
                    "if test -f modules.cer; then\n    cp --no-preserve=mode,ownership --remove-destination"
                    "cat >> modules.cer\n    fi"
                  ]
                  previousAttrs.postBuild;
            });
        })
      ];

      # Enable the four SteamOS platform sysctls provided by nix-gaming.
      programs.steam.platformOptimizations.enable = true;

      # Use the tested x86-64-v3 CachyOS kernel as the normal boot entry. It is compatible with
      # this host's Zen 3 CPU.
      boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-latest-x86_64-v3";

      # Keep an explicitly named stock-kernel entry in the same generation for rollback without
      # changing the rest of the gaming configuration.
      specialisation.stock.configuration = {
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
      };
    };
}
