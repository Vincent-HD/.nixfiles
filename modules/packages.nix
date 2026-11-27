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
      # Shared nix-update wrapper behind every pinned package's passthru.updateScript.
      packageUpdater = pkgs.callPackage ../packages/package-updater {
        nix-update = inputs.nix-update.packages.${pkgs.stdenv.hostPlatform.system}.nix-update;
      };
      # One pin file per ArtCraft app under packages/craft-apps/apps.
      craftAppNames = map (lib.removeSuffix ".nix") (
        builtins.attrNames (builtins.readDir ../packages/craft-apps/apps)
      );

      # Reuse the exact GitHub snapshot for both the source output and Linux package.
      zCodeSource = inputs.z-code;
      zCodeSourcePackage =
        pkgs.runCommand "z-code-source"
          {
            passthru.sourcePath = zCodeSource;
          }
          ''
            mkdir -p "$out"
            cp -R ${zCodeSource}/. "$out/"
          '';
      # Reuse the fork's package definition for both flake consumers and Home Manager.
      zCodePackage = import "${zCodeSource}/nix/default.nix" {
        pkgs = pkgs;
        self = zCodeSource;
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
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.systemd ];
        text = builtins.readFile ../modules/bitwarden/assets/bw-secret.sh;
      };
    in
    {
      packages = {
        agent-browser = pkgs.callPackage ../packages/agent-browser {
          packageUpdater = packageUpdater;
        };
        arch-ops-server = pkgs.callPackage ../packages/arch-ops-server {
          packageUpdater = packageUpdater;
        };
        codeburn = pkgs.callPackage ../packages/codeburn {
          packageUpdater = packageUpdater;
        };
        equicord-prebuilt = pkgs.callPackage ../packages/equicord-prebuilt {
          packageUpdater = packageUpdater;
        };
        cursor-agent = unfreePkgs.callPackage ../packages/cursor-agent {
          packageUpdater = packageUpdater;
        };
        executor = pkgs.callPackage ../packages/executor {
          packageUpdater = packageUpdater;
        };
        handy = pkgs.callPackage ../packages/handy {
          packageUpdater = packageUpdater;
        };
        jj-ryu = pkgs.callPackage ../packages/jj-ryu {
          packageUpdater = packageUpdater;
        };
        lightjj = pkgs.callPackage ../packages/lightjj {
          packageUpdater = packageUpdater;
        };
        opencodev2 = pkgs.callPackage ../packages/opencodev2 {
          packageUpdater = packageUpdater;
        };
        vtask = pkgs.callPackage ../packages/vtask { };
        wifi-audio-streaming = pkgs.callPackage ../packages/wifi-audio-streaming {
          packageUpdater = packageUpdater;
        };
        portless = pkgs.callPackage ../packages/portless {
          packageUpdater = packageUpdater;
        };
        plannotator = pkgs.callPackage ../packages/plannotator {
          packageUpdater = packageUpdater;
        };
        package-updater = packageUpdater;
        bitwarden-secret-tools = bwSecretTools;
        open-pencil = pkgs.callPackage ../packages/open-pencil {
          packageUpdater = packageUpdater;
        };
        open-pencil-mcp = pkgs.callPackage ../packages/open-pencil/mcp { };
      }
      # ArtCraft desktop apps share one builder with one pin file per app.
      // lib.genAttrs craftAppNames (
        appName:
        pkgs.callPackage ../packages/craft-apps {
          appName = appName;
          packageUpdater = packageUpdater;
        }
      )
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        dms-prebuilt = pkgs.callPackage ../packages/dms-prebuilt {
          dmsFlake = inputs.dms;
          packageUpdater = packageUpdater;
        };
        codex = pkgs.callPackage ../packages/codex {
          packageUpdater = packageUpdater;
        };
        cpuid-fault-emulation = pkgs.callPackage ../packages/cpuid-fault-emulation { };
        curseforge = unfreePkgs.callPackage ../packages/curseforge {
          packageUpdater = packageUpdater;
        };
        crosspipe = pkgs.callPackage ../packages/crosspipe {
          packageUpdater = packageUpdater;
        };
        # Bundle the daemon, Quickshell interface, launcher, and optional DMS widget.
        dankmail = pkgs.callPackage ../packages/dankmail {
          packageUpdater = packageUpdater;
        };
        droidcam-client = pkgs.callPackage ../packages/droidcam-client {
          packageUpdater = packageUpdater;
        };
        gamescope-lanczos = pkgs.callPackage ../packages/gamescope-lanczos {
          packageUpdater = packageUpdater;
        };
        lsfg-vk = unfreePkgs.callPackage ../packages/lsfg-vk {
          packageUpdater = packageUpdater;
        };
        # Prebuilt tuyau release binaries, so the Rust workspace is never compiled locally.
        tuyau = pkgs.callPackage ../packages/tuyau {
          packageUpdater = packageUpdater;
        };
        persist-dms = mkBunRunner "persist-dms" ../scripts/persist-dms.ts;
        gpu-burn = cudaPkgs.gpu-burn;
      }
      # The fork package repacks the upstream x86_64 Linux AppImage or arm64 macOS zip.
      //
        lib.optionalAttrs
          (builtins.elem pkgs.stdenv.hostPlatform.system [
            "x86_64-linux"
            "aarch64-darwin"
          ])
          {
            z-code-source = zCodeSourcePackage;
            z-code = zCodePackage;
          };

      # Keep local CLI builds on the same Bun and package-manager versions as Nix rebuilds.
      devShells.vtask = pkgs.mkShell {
        packages = [
          pkgs.bun
          pkgs.nodejs_24
          pkgs.pnpm
          pkgs.git-lfs
        ];
        pnpm_config_pm_on_fail = "ignore";
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
      };
    };
}
