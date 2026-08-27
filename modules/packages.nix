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

      mkBunRunner =
        name: script:
        pkgs.writeTextFile {
          name = name;
          destination = "/bin/${name}";
          executable = true;
          text = ''
            #!${lib.getExe pkgs.bun}
            const module = await import("file://${script}");
            if (typeof module.main === "function") await module.main();
          '';
        };

      mkBunApp = name: script: {
        type = "app";
        program = "${mkBunRunner name script}/bin/${name}";
      };
    in
    {
      packages = {
        agent-browser = pkgs.callPackage ../packages/agent-browser { };
        arch-ops-server = pkgs.callPackage ../packages/arch-ops-server { };
        cursor-agent = unfreePkgs.callPackage ../packages/cursor-agent { };
        executor = pkgs.callPackage ../packages/executor { };
        jj-ryu = pkgs.callPackage ../packages/jj-ryu { };
        lightjj = pkgs.callPackage ../packages/lightjj { };
        opencodex = pkgs.callPackage ../packages/opencodex { };
        papercuts = pkgs.callPackage ../packages/papercuts { };
        t3code = pkgs.callPackage ../packages/t3code { };
        portless = pkgs.callPackage ../packages/portless { };
        plannotator = pkgs.callPackage ../packages/plannotator { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        codex = pkgs.callPackage ../packages/codex { };
        cpuid-fault-emulation = pkgs.callPackage ../packages/cpuid-fault-emulation { };
        curseforge = pkgs.callPackage ../packages/curseforge { };
        crosspipe = pkgs.callPackage ../packages/crosspipe { };
        moonshine = pkgs.callPackage ../packages/moonshine { };
        persist-dms = mkBunRunner "persist-dms" ../scripts/persist-dms.ts;
      };

      apps = {
        update-pins = mkBunApp "update-pins" ../scripts/update-pins.ts;
        update-curseforge = mkBunApp "update-curseforge" ../packages/curseforge/update.ts;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        persist-dms = mkBunApp "persist-dms" ../scripts/persist-dms.ts;
      };
    };
}
