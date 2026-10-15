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
      providerPackages = [
        cursorAgentPackage
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
        description = "Build the Linux composer usage patch independently of the Jujutsu panel.";
      };
      options.custom.t3code.enableJjPanel = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Build the Linux Jujutsu panel and its matching server; disable to exclude this patch.";
      };

      config = {
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
          userSettings.providerInstances.codex = {
            driver = "codex";
            enabled = true;
            config = {
              binaryPath = if isLinux then lib.getExe codexPackage else "codex";
              homePath = "${config.home.homeDirectory}/.codex";
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
