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
      # Input is pinned to 3.15.6 in flake.nix — do not float it to 3.16.x.
      cursorPkg = pkgs.callPackage "${inputs.code-cursor-nix}/package.nix" {
        # The pinned package still uses deprecated nixpkgs aliases. Supply the
        # exact legacy argument shape with current attributes until the pin moves.
        appimageTools = pkgs.appimageTools // {
          extractType2 = pkgs.appimageTools.extract;
        };
        xorg = {
          libxkbfile = pkgs.libxkbfile;
          libX11 = pkgs.libx11;
          libXcomposite = pkgs.libxcomposite;
          libXdamage = pkgs.libxdamage;
          libXext = pkgs.libxext;
          libXfixes = pkgs.libxfixes;
          libXrandr = pkgs.libxrandr;
          libxcb = pkgs.libxcb;
        };
      };
      cursorAgentPkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
    in
    lib.mkMerge [
      {
        home.packages = [
          cursorAgentPkg
          pkgs.vscode
          cursorPkg
          pkgs.neovim
          pkgs.vim
        ];

        # Prefer Cursor from interactive shells without hijacking PATH for
        # launchers that resolve bare `code` via desktop entries.
        programs.zsh.shellAliases.code = "cursor";
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

        # On Niri, VS Code cannot auto-detect an OS keyring even though
        # gnome-keyring already provides org.freedesktop.secrets.
        # Pin the Electron password store explicitly.
        home.file.".vscode/argv.json" = {
          force = true;
          text = builtins.toJSON {
            "enable-crash-reporter" = true;
            "crash-reporter-id" = "eb44dfe9-2bdb-4571-8c19-d8b205ce9eba";
            "password-store" = "gnome-libsecret";
          };
        };
      })
    ];
}
