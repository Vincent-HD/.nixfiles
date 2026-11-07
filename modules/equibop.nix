{
  # Manage Equibop and its Equicord plugin settings in Home Manager on both hosts.
  config.flake.modules.homeManager.equibop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Keep the game-only Vulkan layer out of Equibop's capture process.
      equibopLinux = pkgs.symlinkJoin {
        name = "equibop-without-lsfg";
        paths = [ pkgs.equibop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/equibop" --set DISABLE_LSFGVK 1
        '';
        meta.mainProgram = "equibop";
      };
      equicordPrebuilt = pkgs.callPackage ../packages/equicord-prebuilt { };
      equibopDataDir =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${config.home.homeDirectory}/Library/Application Support/equibop"
        else
          "${config.xdg.configHome}/equibop";
      equicordSettings = pkgs.writeText "equicord-managed-settings.json" (
        builtins.toJSON {
          plugins = {
            "Hey wake up!".enabled = true;
            BiggerStreamPreview.enabled = true;
            FakeNitro.enabled = true;
            StreamingCodecDisabler.enabled = true;
            BetterFolders.enabled = true;
            VoiceMessages.enabled = true;
            VolumeBooster.enabled = true;
          };
        }
      );
    in
    {
      programs.equibop = {
        enable = true;
        package = if pkgs.stdenv.hostPlatform.isLinux then equibopLinux else null;
      };

      # Merge managed plugins into writable settings before old Home Manager links are removed.
      home.activation.equicordWritableSettings =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            run ${pkgs.writeShellScript "equicord-writable-settings" ''
              set -eu
              settings_dir="$1/settings"
              settings_file="$settings_dir/settings.json"
              mkdir -p "$settings_dir"
              temporary=$(mktemp "$settings_dir/.settings.XXXXXX")
              trap "rm -f \"$temporary\"" EXIT
              if [ -f "$settings_file" ]; then
                ${pkgs.jq}/bin/jq -s ".[0] * .[1]" "$settings_file" "$2" > "$temporary"
              else
                ${pkgs.jq}/bin/jq . "$2" > "$temporary"
              fi
              mv -f "$temporary" "$settings_file"
            ''} ${lib.escapeShellArg equibopDataDir} ${lib.escapeShellArg (toString equicordSettings)}
          '';

      # Electron's generated autostart entry otherwise keeps obsolete Nix store paths.
      xdg.configFile."autostart/equibop.desktop" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Equibop
          Comment=Start Equibop
          Exec=${lib.getExe equibopLinux}
          Icon=equibop
          Terminal=false
          StartupNotify=false
        '';
      };

      # Point Equibop at the pinned Equicord release without replacing its other state.
      home.activation.equibopCustomEquicord = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        state_dir=${lib.escapeShellArg equibopDataDir}
        state_file="$state_dir/state.json"
        if [ -f "$state_file" ]; then
          state=$(${pkgs.jq}/bin/jq --arg dir ${lib.escapeShellArg (toString equicordPrebuilt)} '.equicordDir = $dir' "$state_file")
        else
          state=$(${pkgs.jq}/bin/jq -n --arg dir ${lib.escapeShellArg (toString equicordPrebuilt)} '{equicordDir: $dir}')
        fi
        run mkdir -p "$state_dir"
        run --silence ${pkgs.runtimeShell} -c 'printf "%s\n" "$1" > "$2"' _ "$state" "$state_file"
      '';
    };

  # Install the native macOS app through the upstream-recommended Homebrew cask.
  config.flake.modules.darwin.equibop =
    { ... }:
    {
      homebrew.casks = [ "equibop" ];
    };
}
