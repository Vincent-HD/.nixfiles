{ inputs, ... }:
{
  config.flake.modules.homeManager.codingEditors =
    {
      pkgs,
      lib,
      ...
    }:
    let
      # Re-evaluate code-cursor-nix with this flake's package set so Cursor
      # stays aligned with the rest of the host configuration.
      cursorPkg = pkgs.callPackage "${inputs.code-cursor-nix}/package.nix" { };

      # `pkgs.vscode` also installs `bin/code`. A higher-priority wrapper makes
      # every `code` invocation run Cursor without relying on shell aliases.
      codeCliWrapsCursor = pkgs.lib.hiPrio (
        pkgs.writeShellScriptBin "code" ''
          exec ${pkgs.lib.getExe cursorPkg} "$@"
        ''
      );

      cursorAgentPkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
    in
    lib.mkMerge [
      {
        home.packages = [
          codeCliWrapsCursor
          cursorAgentPkg
          (pkgs.lib.lowPrio pkgs.vscode)
          cursorPkg
          pkgs.neovim
          pkgs.vim
        ];
      }

      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        # Cursor's upstream desktop file uses an icon name that KDE does not
        # resolve here.
        home.file.".local/share/applications/cursor.desktop".source = pkgs.writeText "cursor.desktop" ''
          [Desktop Entry]
          Name=Cursor
          Comment=The AI Code Editor.
          GenericName=Text Editor
          Exec=${pkgs.lib.getExe cursorPkg} %F
          Icon=${cursorPkg}/share/icons/hicolor/512x512/apps/cursor.png
          Type=Application
          StartupNotify=false
          StartupWMClass=Cursor
          Categories=TextEditor;Development;IDE;
          MimeType=application/x-cursor-workspace;
          Actions=new-empty-window;
          Keywords=cursor;

          X-AppImage-Version=${cursorPkg.version}

          [Desktop Action new-empty-window]
          Name=New Empty Window
          Exec=${pkgs.lib.getExe cursorPkg} --new-window %F
          Icon=${cursorPkg}/share/icons/hicolor/512x512/apps/cursor.png
        '';
      })
    ];
}
