{ inputs, ... }:
let
  discardDrvContexts = builtins.mapAttrs (_name: builtins.unsafeDiscardStringContext);
in
{
  config.perSystem =
    { pkgs, ... }:
    let
      mkEvaluationCheck =
        name: drvPaths: pkgs.writeText name (builtins.toJSON (discardDrvContexts drvPaths));
    in
    {
      # Expose the repository-wide Nix formatter through `nix fmt`.
      formatter = pkgs.nixfmt-tree;

      checks = {
        deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
          deadnix --fail ${../.}
          touch "$out"
        '';

        update-pins-tests =
          pkgs.runCommand "update-pins-tests"
            {
              nativeBuildInputs = [
                pkgs.bash
                pkgs.bun
                pkgs.gnugrep
                pkgs.jq
                pkgs.nix
              ];
            }
            ''
              export HOME="$TMPDIR/home"
              export NIX_CONFIG="experimental-features = nix-command flakes"
              export UPDATE_PINS_REPO_ROOT="$TMPDIR/repo"
              mkdir -p "$HOME" "$UPDATE_PINS_REPO_ROOT/scripts" "$UPDATE_PINS_REPO_ROOT/modules/command-line/assets"
              mkdir -p "$TMPDIR/package-updater"
              cp ${../scripts/update-pins.ts} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts"
              cp ${../scripts/update-pins.test.ts} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.test.ts"
              cp ${../scripts/nrs.test.ts} "$UPDATE_PINS_REPO_ROOT/scripts/nrs.test.ts"
              cp ${../modules/command-line/assets/nrs} "$UPDATE_PINS_REPO_ROOT/modules/command-line/assets/nrs"
              cp ${../packages/package-updater/update-package.ts} "$TMPDIR/package-updater/update-package.ts"
              cp ${../packages/package-updater/update-package.test.ts} "$TMPDIR/package-updater/update-package.test.ts"

              bun test "$UPDATE_PINS_REPO_ROOT/scripts/nrs.test.ts"
              bun test "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.test.ts"
              bun test "$TMPDIR/package-updater/update-package.test.ts"

              touch "$out"
            '';

        statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check --config ${../checks/statix.toml} ${../.}
          touch "$out"
        '';
      }
      // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        fallback-evaluations =
          let
            extendLinux = modules: inputs.self.nixosConfigurations.pc-fixe.extendModules { inherit modules; };
            moonshine = extendLinux [ inputs.self.modules.nixos.moonshine ];
          in
          mkEvaluationCheck "fallback-evaluations.json" {
            moonshine = moonshine.config.system.build.toplevel.drvPath;
          };

        persist-dms-tests =
          pkgs.runCommand "persist-dms-tests"
            {
              nativeBuildInputs = [
                pkgs.bun
                pkgs.git
              ];
            }
            ''
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME/test"
              cp ${../scripts/persist-dms.ts} "$HOME/test/persist-dms.ts"
              cp ${../scripts/persist-dms.test.ts} "$HOME/test/persist-dms.test.ts"
              cd "$HOME/test"
              bun test persist-dms.test.ts
              touch "$out"
            '';
      }
      // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        fallback-evaluations =
          let
            homebrew = inputs.self.darwinConfigurations.vincent-macbook-pro.extendModules {
              modules = [ inputs.self.modules.darwin.homebrew ];
            };
          in
          mkEvaluationCheck "fallback-evaluations.json" {
            homebrew = homebrew.system.drvPath;
          };
      };
    };
}
