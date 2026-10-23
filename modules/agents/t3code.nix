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
      t3codePackage =
        if config.custom.t3code.enableUsagePatch && config.custom.t3code.enableJjPanel then
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-patched
        else if config.custom.t3code.enableJjPanel then
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-jj
        else if config.custom.t3code.enableUsagePatch then
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code-usage
        else
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
      cursorAgentPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      codexPackage =
        if isLinux then inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.codex else null;
      codexBinary = if isLinux then lib.getExe codexPackage else "/opt/homebrew/bin/codex";
      # Keep T3 subscription accounts on the direct ChatGPT endpoint.
      codexLaunchArgs = lib.escapeShellArgs [
        "-c"
        ''model_provider="openai"''
        "-c"
        ''openai_base_url="https://chatgpt.com/backend-api/codex"''
      ];
      opencodePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.opencodev2;
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
        name = "t3code-${t3codePackage.version}-wrapped";
        paths = [ t3codePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/t3code" --set T3CODE_DISABLE_AUTO_UPDATE true --prefix PATH : "${lib.makeBinPath providerPackages}:${config.home.profileDirectory}/bin" ${extraWrap}
        '';
      };
    in
    {
      options.custom.t3code.enableUsagePatch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Build the Linux composer usage patch independently of the Jujutsu panel. `nrs --no-t3-usage` overrides one switch.";
      };
      options.custom.t3code.enableJjPanel = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Build the Linux Jujutsu panel and its matching server. `nrs --no-t3-jj` overrides one switch.";
      };

      config = {
        # `nrs` exports these for one impure switch. Empty keeps the host value.
        custom.t3code.enableUsagePatch = lib.mkIf (isLinux && builtins.getEnv "NRS_T3_USAGE" != "") (
          lib.mkOverride 90 (builtins.getEnv "NRS_T3_USAGE" != "0")
        );
        custom.t3code.enableJjPanel = lib.mkIf (isLinux && builtins.getEnv "NRS_T3_JJ" != "") (
          lib.mkOverride 90 (builtins.getEnv "NRS_T3_JJ" != "0")
        );
        assertions = [
          {
            assertion = !config.custom.t3code.enableUsagePatch || isLinux;
            message = "The T3 Code usage patch currently supports Linux only.";
          }
          {
            assertion = !config.custom.t3code.enableJjPanel || isLinux;
            message = "The T3 Code Jujutsu panel currently supports Linux only.";
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
          name = "T3 Code (Nightly)";
          comment = "T3 Code desktop build";
          exec = "t3code %U";
          icon =
            if isLinux then
              "${t3codePackage.extracted}/usr/share/icons/hicolor/512x512/apps/t3code.png"
            else
              "t3code";
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
