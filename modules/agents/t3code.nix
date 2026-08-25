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
      t3codePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
      cursorAgentPackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
      isLinux = pkgs.stdenv.hostPlatform.isLinux;
      codexPackage =
        if isLinux then inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.codex else null;
      providerPackages = [ cursorAgentPackage ] ++ lib.optional (codexPackage != null) codexPackage;
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
          wrapProgram "$out/bin/t3code" --prefix PATH : "${lib.makeBinPath providerPackages}:${config.home.profileDirectory}/bin" ${extraWrap}
        '';
      };
    in
    {
      home.packages = [ t3code ];

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
}
