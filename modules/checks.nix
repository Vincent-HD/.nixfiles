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
              cp ${../scripts/update-pins.ts} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts"
              cp ${../scripts/update-pins.json} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.json"
              cp ${../scripts/nrs.test.ts} "$UPDATE_PINS_REPO_ROOT/scripts/nrs.test.ts"
              cp ${../scripts/update-pins.test.ts} "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.test.ts"
              cp ${../modules/command-line/assets/nrs} "$UPDATE_PINS_REPO_ROOT/modules/command-line/assets/nrs"

              bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" --list >/dev/null
              if bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" --dry-run --only unknown-entry; then
                echo "unknown update entry unexpectedly succeeded" >&2
                exit 1
              fi
              if bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" \
                --dry-run --only screen-capture-toolbar --validate fast \
                >"$TMPDIR/manual.stdout" 2>"$TMPDIR/manual.stderr"; then
                echo "manual-only update selection unexpectedly succeeded" >&2
                exit 1
              fi
              grep --fixed-strings 'screen-capture-toolbar (manual)' "$TMPDIR/manual.stdout"
              grep --fixed-strings 'validation was not run' "$TMPDIR/manual.stderr"

              jq '.updates += [{
                "name": "enabled-manual-test",
                "type": "manual",
                "enabled": true,
                "command": ["nix", "flake", "update", "enabled-manual-test"]
              }]' "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.json" > "$TMPDIR/update-pins.json"
              mv "$TMPDIR/update-pins.json" "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.json"
              if bun "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.ts" \
                --dry-run --only enabled-manual-test \
                >"$TMPDIR/enabled-manual.stdout" 2>"$TMPDIR/enabled-manual.stderr"; then
                echo "manually classified update entry unexpectedly succeeded" >&2
                exit 1
              fi
              grep --fixed-strings 'enabled-manual-test (manual)' "$TMPDIR/enabled-manual.stdout"
              grep --fixed-strings 'validation was not run' "$TMPDIR/enabled-manual.stderr"

              bun test "$UPDATE_PINS_REPO_ROOT/scripts/nrs.test.ts"
              bun test "$UPDATE_PINS_REPO_ROOT/scripts/update-pins.test.ts"

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
