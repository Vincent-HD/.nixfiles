{ inputs, ... }:
{
  config.perSystem =
    { pkgs, lib, ... }:
    let
      # Cursor Agent is proprietary; keep its standalone flake package
      # evaluable even though the generic per-system package set is free-only.
      unfreePkgs = import inputs.nixpkgs {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };

      mkBunApp =
        name: script:
        let
          runner = pkgs.writeTextFile {
            name = name;
            destination = "/bin/${name}";
            executable = true;
            text = ''
              #!${lib.getExe pkgs.bun}
              await import("file://${script}");
            '';
          };
        in
        {
          type = "app";
          program = "${runner}/bin/${name}";
        };
    in
    {
      packages = {
        cursor-agent = unfreePkgs.callPackage ../packages/cursor-agent { };
        jj-ryu = pkgs.callPackage ../packages/jj-ryu { };
        lightjj = pkgs.callPackage ../packages/lightjj { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        codex = pkgs.callPackage ../packages/codex { };
        curseforge = pkgs.callPackage ../packages/curseforge { };
        crosspipe = pkgs.callPackage ../packages/crosspipe { };
        fusion360 = unfreePkgs.callPackage ../packages/fusion360 { };
      };

      apps = {
        update-pins = mkBunApp "update-pins" ../scripts/update-pins.ts;
        update-curseforge = mkBunApp "update-curseforge" ../packages/curseforge/update.ts;
      };
    };
}
