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
      equicordWithHeyWakeUp = pkgs.equicord.overrideAttrs (previous: {
        postPatch = (previous.postPatch or "") + ''
          mkdir -p src/userplugins/heyWakeUp
          cp ${./equibop-assets/heyWakeUp/index.tsx} src/userplugins/heyWakeUp/index.tsx
          cp ${./equibop-assets/heyWakeUp/style.css} src/userplugins/heyWakeUp/style.css
        '';
      });
      equibopDataDir =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${config.home.homeDirectory}/Library/Application Support/equibop"
        else
          "${config.xdg.configHome}/equibop";
    in
    {
      programs.equibop = {
        enable = true;
        package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.equibop else null;

        equicord.settings.plugins = {
          "Hey wake up!".enabled = true;
          BiggerStreamPreview.enabled = true;
          FakeNitro.enabled = true;
          StreamingCodecDisabler.enabled = true;
          BetterFolders.enabled = true;
          VoiceMessages.enabled = true;
          VolumeBooster.enabled = true;
        };
      };

      # Point Equibop at the Nix-built Equicord without replacing its other state.
      home.activation.equibopCustomEquicord = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        state_dir=${lib.escapeShellArg equibopDataDir}
        state_file="$state_dir/state.json"
        if [ -f "$state_file" ]; then
          state=$(${pkgs.jq}/bin/jq --arg dir ${lib.escapeShellArg (toString equicordWithHeyWakeUp)} '.equicordDir = $dir' "$state_file")
        else
          state=$(${pkgs.jq}/bin/jq -n --arg dir ${lib.escapeShellArg (toString equicordWithHeyWakeUp)} '{equicordDir: $dir}')
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
