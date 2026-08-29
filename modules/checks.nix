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

        opencodex-model-tests =
          pkgs.runCommand "opencodex-model-tests"
            {
              nativeBuildInputs = [ pkgs.bun ];
            }
            ''
              cp ${../modules/agents/assets/opencodex-models-vscode/opencodex-models-vscode.ts} \
                opencodex-models-vscode.ts
              cp ${../modules/agents/assets/opencodex-models-vscode/opencodex-models-vscode.unit.test.ts} \
                opencodex-models-vscode.unit.test.ts
              bun test opencodex-models-vscode.unit.test.ts
              touch "$out"
            '';

        update-pins-tests =
          pkgs.runCommand "update-pins-tests"
            {
              nativeBuildInputs = [
                pkgs.bun
                pkgs.gnugrep
                pkgs.nix
              ];
            }
            ''
              export HOME="$TMPDIR/home"
              export NIX_CONFIG="experimental-features = nix-command flakes"
              export UPDATE_PINS_REPO_ROOT="$TMPDIR/repo"
              mkdir -p "$HOME" "$UPDATE_PINS_REPO_ROOT/scripts"
              cp ${../scripts/update-pins.ts} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts"
              cp ${../scripts/update-pins.json} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.json"

              bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" --list >/dev/null
              if bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" --dry-run --only unknown-entry; then
                echo "unknown update entry unexpectedly succeeded" >&2
                exit 1
              fi
              bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" \
                --dry-run --only screen-capture-toolbar \
                | grep --fixed-strings 'screen-capture-toolbar (manual)'

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
            noctalia = extendLinux [
              inputs.self.modules.nixos.noctalia
              {
                home-manager.users.vincent.imports = [
                  inputs.self.modules.homeManager.noctalia
                  inputs.self.modules.homeManager."noctalia-plugins-dependencies"
                ];
              }
            ];
            plasma = extendLinux [
              inputs.self.modules.nixos.plasma
              {
                home-manager.users.vincent.imports = [ inputs.self.modules.homeManager.plasma ];
              }
            ];
          in
          mkEvaluationCheck "fallback-evaluations.json" {
            moonshine = moonshine.config.system.build.toplevel.drvPath;
            noctalia = noctalia.config.system.build.toplevel.drvPath;
            plasma = plasma.config.system.build.toplevel.drvPath;
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
            homebrew = inputs.self.darwinConfigurations.macbook-pro.extendModules {
              modules = [ inputs.self.modules.darwin.homebrew ];
            };
          in
          mkEvaluationCheck "fallback-evaluations.json" {
            homebrew = homebrew.system.drvPath;
          };
      };
    };
}
