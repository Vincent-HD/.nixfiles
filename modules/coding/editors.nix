{ inputs, ... }:
{
  config.flake.modules.homeManager.codingEditors =
    {
      pkgs,
      lib,
      ...
    }:
    let
      # Cursor's upstream Nix input currently serves an old macOS ARM bundle.
      # Use the locally pinned release there while retaining the upstream package on Linux.
      cursorPkg =
        if pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isDarwin then
          pkgs.callPackage ../../packages/cursor { }
        else
          pkgs.callPackage "${inputs.code-cursor-nix}/package.nix" { };

      # The macOS package is an application bundle without a `bin/cursor` entrypoint.
      cursorCli =
        if pkgs.stdenv.hostPlatform.isDarwin then
          pkgs.writeShellScriptBin "cursor" ''
            exec ${cursorPkg}/Applications/Cursor.app/Contents/MacOS/Cursor "$@"
          ''
        else
          cursorPkg;

      # `pkgs.vscode` also installs `bin/code`. A higher-priority wrapper makes
      # every `code` invocation run Cursor without relying on shell aliases.
      codeCliWrapsCursor = pkgs.lib.hiPrio (
        pkgs.writeShellScriptBin "code" ''
          exec ${pkgs.lib.getExe cursorCli} "$@"
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
        ]
        ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin cursorCli;
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
