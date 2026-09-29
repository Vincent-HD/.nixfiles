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
      # Keep the CUDA-enabled stress tool reproducible without enabling CUDA support for every package.
      cudaPkgs = import inputs.nixpkgs {
        system = pkgs.stdenv.hostPlatform.system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
        };
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

      mkBunApp =
        {
          name,
          description,
          script,
        }:
        {
          type = "app";
          program = "${mkBunRunner name script}/bin/${name}";
          meta.description = description;
        };

      # Synchronize declared Bitwarden secrets to local files and load them for managed children.
      bwSecretTools = pkgs.writeShellApplication {
        name = "bw-secret";
        runtimeInputs = [
          pkgs.bitwarden-cli
          pkgs.coreutils
          pkgs.jq
        ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.systemd ];
        text = builtins.readFile ../modules/bitwarden/assets/bw-secret.sh;
      };
    in
    {
      packages = {
        agent-browser = pkgs.callPackage ../packages/agent-browser { };
        arch-ops-server = pkgs.callPackage ../packages/arch-ops-server { };
        codeburn = pkgs.callPackage ../packages/codeburn { };
        cursor-agent = unfreePkgs.callPackage ../packages/cursor-agent { };
        executor = pkgs.callPackage ../packages/executor { };
        jj-ryu = pkgs.callPackage ../packages/jj-ryu { };
        lightjj = pkgs.callPackage ../packages/lightjj { };
        opencodex = pkgs.callPackage ../packages/opencodex { };
        papercuts = pkgs.callPackage ../packages/papercuts { };
        t3code = pkgs.callPackage ../packages/t3code { };
        wifi-audio-streaming = pkgs.callPackage ../packages/wifi-audio-streaming { };
        portless = pkgs.callPackage ../packages/portless { };
        plannotator = pkgs.callPackage ../packages/plannotator { };
        bitwarden-secret-tools = bwSecretTools;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        codex = pkgs.callPackage ../packages/codex { };
        cpuid-fault-emulation = pkgs.callPackage ../packages/cpuid-fault-emulation { };
        curseforge = unfreePkgs.callPackage ../packages/curseforge { };
        crosspipe = pkgs.callPackage ../packages/crosspipe { };
        # Bundle the daemon, Quickshell interface, launcher, and optional DMS widget.
        dankmail = pkgs.callPackage ../packages/dankmail { };
        gamescope-lanczos = pkgs.callPackage ../packages/gamescope-lanczos { };
        lsfg-vk = unfreePkgs.callPackage ../packages/lsfg-vk { };
        persist-dms = mkBunRunner "persist-dms" ../scripts/persist-dms.ts;
        gpu-burn = cudaPkgs.gpu-burn;
      };

      apps = {
        update-pins = mkBunApp {
          name = "update-pins";
          description = "Update registered package pins and flake inputs";
          script = ../scripts/update-pins.ts;
        };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        persist-dms = mkBunApp {
          name = "persist-dms";
          description = "Persist non-default DankMaterialShell settings";
          script = ../scripts/persist-dms.ts;
        };
        update-curseforge = mkBunApp {
          name = "update-curseforge";
          description = "Update the pinned CurseForge AppImage";
          script = ../packages/curseforge/update.ts;
        };
      };
    };
}
