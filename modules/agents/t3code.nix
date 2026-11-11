{ inputs, ... }:
{
  config.flake.modules.homeManager.agentT3Code =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      # The Z Code fork is packaged for x86_64 Linux and Apple Silicon macOS.
      usesZCode = builtins.hasAttr "z-code" inputs.self.packages.${system};
      t3codePackage =
        if usesZCode then inputs.self.packages.${system}.z-code else inputs.self.packages.${system}.t3code;
      t3codeVersion = t3codePackage.version or t3codePackage.upstreamVersion;
      cursorAgentPackage = inputs.self.packages.${system}.cursor-agent;
      codexPackage = if isLinux then inputs.self.packages.${system}.codex else null;
      codexBinary = if isLinux then lib.getExe codexPackage else "/opt/homebrew/bin/codex";
      # Keep T3 subscription accounts on the direct ChatGPT endpoint.
      codexLaunchArgs = lib.escapeShellArgs [
        "-c"
        ''model_provider="openai"''
        "-c"
        ''openai_base_url="https://chatgpt.com/backend-api/codex"''
      ];
      opencodePackage = inputs.self.packages.${system}.opencodev2;
      providerPackages = [
        cursorAgentPackage
        config.programs.claude-code.package
        opencodePackage
        pkgs.git
        pkgs.gh
        pkgs.jujutsu
      ]
      ++ lib.optional (codexPackage != null) codexPackage;
      extraWrap =
        if isLinux then
          ''--set-default CODEX_CLI_PATH ${lib.getExe codexPackage} --add-flags "--no-sandbox" --add-flags "--ozone-platform-hint=auto"''
        else
          "";

      # GUI-launched T3 Code does not reliably inherit the Home Manager PATH, and
      # it looks up provider CLIs plus CODEX_CLI_PATH the same way the AUR wrapper does.
      t3code = pkgs.symlinkJoin {
        name = "t3code-${t3codeVersion}-wrapped";
        paths = [ t3codePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/t3code" --set T3CODE_DISABLE_AUTO_UPDATE true --prefix PATH : "${lib.makeBinPath providerPackages}:${config.home.profileDirectory}/bin" ${extraWrap}
          ${lib.optionalString usesZCode ''
            # Route every fork launcher through the same managed T3 Code wrapper.
            rm -f "$out/bin/zcode" "$out/bin/z-code"
            ln -s t3code "$out/bin/zcode"
            ln -s t3code "$out/bin/z-code"
          ''}
        '';
      };
    in
    {
      config = {
        # Merge declared preferences into writable files so UI edits remain possible.
        programs.t3code = {
          enable = true;
          package = t3code;
          mutableUserSettings = true;
          mutableKeybindings = true;
          mutableClientSettings = true;
          # Pin every provider executable, including the second Codex account:
          # GUI and long-running processes can retain an older inherited PATH.
          userSettings.providerInstances = {
            codex = {
              driver = "codex";
              enabled = true;
              config = {
                setupMode = "existing";
                binaryPath = codexBinary;
                homePath = "${config.home.homeDirectory}/.codex";
                launchArgs = codexLaunchArgs;
              };
            };
            claudeAgent = {
              driver = "claudeAgent";
              config.binaryPath = lib.getExe config.programs.claude-code.package;
            };
            cursor = {
              driver = "cursor";
              config.binaryPath = lib.getExe' cursorAgentPackage "cursor-agent";
            };
            opencode = {
              driver = "opencode";
              config.binaryPath = lib.getExe opencodePackage;
            };
          }
          // lib.optionalAttrs isLinux {
            # Preserve Evvi's existing authentication and independent state.
            codex-evvi = {
              driver = "codex";
              config = {
                setupMode = "existing";
                binaryPath = codexBinary;
                homePath = "${config.home.homeDirectory}/.codex-evvi";
                launchArgs = codexLaunchArgs;
              };
            };
          };
        };

        xdg.desktopEntries.t3code = lib.mkIf isLinux {
          name = if usesZCode then "zcode" else "T3 Code (Nightly)";
          comment = if usesZCode then "Z Code desktop build" else "T3 Code desktop build";
          exec = "t3code %U";
          # Read the icon from the selected package so it matches its extracted AppImage.
          icon = "${t3codePackage.extracted}/usr/share/icons/hicolor/512x512/apps/t3code.png";
          terminal = false;
          categories = [ "Development" ];
          mimeType = [
            "x-scheme-handler/t3code"
            "x-scheme-handler/t3code-dev"
          ];
          settings = {
            StartupWMClass = "t3code";
          };
        };
      };
    };
}
