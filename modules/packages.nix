{
  config.perSystem =
    { pkgs, lib, ... }:
    let
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
        jj-ryu = pkgs.callPackage ../packages/jj-ryu { };
        lightjj = pkgs.callPackage ../packages/lightjj { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        codex = pkgs.callPackage ../packages/codex { };
        curseforge = pkgs.callPackage ../packages/curseforge { };
        crosspipe = pkgs.callPackage ../packages/crosspipe { };
      };

      apps = {
        update-pins = mkBunApp "update-pins" ../scripts/update-pins.ts;
        update-curseforge = mkBunApp "update-curseforge" ../packages/curseforge/update.ts;
      };
    };
}
