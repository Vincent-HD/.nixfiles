{ inputs, ... }:
{
  config.flake.modules.darwin.agentT3Code =
    { pkgs, ... }:
    {
      # nix-darwin copies system application bundles into /Applications/Nix Apps.
      environment.systemPackages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code
      ];
    };

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
      isX86_64Linux = system == "x86_64-linux";
      zCodeEnabled = config.custom.t3code.enableZCode;
      t3codeBasePackage = inputs.self.packages.${system}.t3code;
      zCodePackage =
        if isX86_64Linux then
          inputs.self.packages.${system}.z-code
        else
          throw "The Z Code fork package currently supports x86_64 Linux only.";
      patchedT3codePackage =
        if config.custom.t3code.enableTemporaryThreads then
          let
            patchedWeb = pkgs.callPackage ../../packages/t3code-web {
              enableUsagePatch = config.custom.t3code.enableUsagePatch;
              enableJjPanel = config.custom.t3code.enableJjPanel;
              enableTemporaryThreads = true;
            };
          in
          pkgs.callPackage ../../packages/t3code-patched {
            t3code = t3codeBasePackage;
            t3code-web = patchedWeb;
            enableUsagePatch = config.custom.t3code.enableUsagePatch;
            enableJjPanel = config.custom.t3code.enableJjPanel;
          }
        else if config.custom.t3code.enableUsagePatch && config.custom.t3code.enableJjPanel then
          inputs.self.packages.${system}.t3code-patched
        else if config.custom.t3code.enableJjPanel then
          inputs.self.packages.${system}.t3code-jj
        else if config.custom.t3code.enableUsagePatch then
          inputs.self.packages.${system}.t3code-usage
        else
          t3codeBasePackage;
      t3codePackage = if zCodeEnabled then zCodePackage else patchedT3codePackage;
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
          ${lib.optionalString zCodeEnabled ''
            # Route every fork launcher through the same managed T3 Code wrapper.
            rm -f "$out/bin/zcode" "$out/bin/z-code"
            ln -s t3code "$out/bin/zcode"
            ln -s t3code "$out/bin/z-code"
          ''}
        '';
      };
    in
    {
      options.custom.t3code.enableZCode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use the pinned Z Code fork on x86_64 Linux; `nrs --no-z-code` selects upstream T3 Code for one switch.";
      };
      options.custom.t3code.enableUsagePatch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Include the composer usage patch in the Linux upstream fallback. `nrs --no-t3-usage` selects the fallback and drops this patch for one switch.";
      };
      options.custom.t3code.enableJjPanel = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Include the Jujutsu panel and matching server in the Linux upstream fallback. `nrs --no-t3-jj` selects the fallback and drops this patch for one switch.";
      };
      options.custom.t3code.enableTemporaryThreads = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Include the temporary conversations patch in the Linux upstream fallback. `nrs --no-t3-temporary` selects the fallback and drops this patch for one switch.";
      };

      config = {
        # `nrs` exports these for one impure switch. Empty keeps the host value.
        custom.t3code.enableZCode = lib.mkIf (isLinux && builtins.getEnv "NRS_Z_CODE" != "") (
          lib.mkOverride 90 (builtins.getEnv "NRS_Z_CODE" != "0")
        );
        custom.t3code.enableUsagePatch = lib.mkIf (isLinux && builtins.getEnv "NRS_T3_USAGE" != "") (
          lib.mkOverride 90 (builtins.getEnv "NRS_T3_USAGE" != "0")
        );
        custom.t3code.enableJjPanel = lib.mkIf (isLinux && builtins.getEnv "NRS_T3_JJ" != "") (
          lib.mkOverride 90 (builtins.getEnv "NRS_T3_JJ" != "0")
        );
        custom.t3code.enableTemporaryThreads = lib.mkIf (
          isLinux && builtins.getEnv "NRS_T3_TEMPORARY" != ""
        ) (lib.mkOverride 90 (builtins.getEnv "NRS_T3_TEMPORARY" != "0"));
        assertions = [
          {
            assertion = !zCodeEnabled || isX86_64Linux;
            message = "The Z Code fork package currently supports x86_64 Linux only.";
          }
          {
            assertion = !config.custom.t3code.enableUsagePatch || isLinux;
            message = "The T3 Code usage patch currently supports Linux only.";
          }
          {
            assertion = !config.custom.t3code.enableJjPanel || isLinux;
            message = "The T3 Code Jujutsu panel currently supports Linux only.";
          }
          {
            assertion = !config.custom.t3code.enableTemporaryThreads || isLinux;
            message = "The T3 Code temporary conversations patch currently supports Linux only.";
          }
        ];
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
          name = if zCodeEnabled then "zcode" else "T3 Code (Nightly)";
          comment = if zCodeEnabled then "Z Code desktop build" else "T3 Code desktop build";
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
