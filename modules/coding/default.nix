{ inputs, config, ... }:
let
  username = config.flake.username;
in
{
  # ============================================================================
  # NixOS System Configuration
  # ============================================================================
  config.flake.modules.nixos.coding =
    { ... }:
    {
      programs.nix-ld.enable = true;

      virtualisation.docker.enable = true;

      users.users.${username}.extraGroups = [ "docker" ];
    };

  # ============================================================================
  # Home Manager Configuration
  # ============================================================================
  config.flake.modules.homeManager.coding =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # ------------------------------------------------------------------------
      # Package definitions
      # ------------------------------------------------------------------------
      cursorPkg = inputs.code-cursor-nix.packages.${pkgs.system}.cursor;

      # `pkgs.vscode` also installs `bin/code`. A higher-priority wrapper makes every
      # `code` invocation (shell, git, scripts) run Cursor instead, similar to installing
      # the editor's CLI on PATH without relying on shell aliases.
      codeCliWrapsCursor = pkgs.lib.hiPrio (
        pkgs.writeShellScriptBin "code" ''
          exec ${pkgs.lib.getExe cursorPkg} "$@"
        ''
      );

      opencode-bin = "${pkgs.opencode}/bin/opencode";

      # Wrapper: bare `opencode` attaches to the running service with the current directory.
      # Any subcommand (run, serve, auth, …) is passed through to the real binary unchanged.
      opencode-wrapper = pkgs.writeShellScriptBin "opencode" ''
        if [ $# -gt 0 ]; then
          exec ${opencode-bin} "$@"
        fi
        exec ${opencode-bin} attach http://localhost:4096 --dir "$PWD"
      '';

      opencodeSettings = builtins.fromJSON (builtins.readFile ./assets/opencode.jsonc);
      opencodeSettingsWithHome = lib.recursiveUpdate opencodeSettings {
        mcp.github.headers.Authorization = "Bearer {file:${config.home.homeDirectory}/.config/opencode/github-token}";
      };
      opencodeSettingsForPlatform =
        if pkgs.stdenv.hostPlatform.isDarwin then
          opencodeSettingsWithHome
          // {
            mcp = builtins.removeAttrs opencodeSettingsWithHome.mcp [
              "github"
              "nixos"
            ];
          }
        else
          opencodeSettingsWithHome;

      nixswitch = pkgs.writeShellScriptBin "nixswitch" ''
        case "$(uname -s)" in
          Darwin)
            exec sudo darwin-rebuild switch --flake "$HOME/.nixfiles#macbook-pro"
            ;;
          Linux)
            exec sudo nixos-rebuild switch --flake "$HOME/.nixfiles#pc-fixe"
            ;;
          *)
            echo "Unsupported operating system: $(uname -s)" >&2
            exit 1
            ;;
        esac
      '';
    in
    lib.mkMerge [
      {
        # ------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------
        home.packages = [
          inputs.self.packages.${pkgs.system}.jj-ryu
          codeCliWrapsCursor
          (pkgs.lib.lowPrio pkgs.vscode)
          cursorPkg
          opencode-wrapper
          nixswitch
          pkgs.neovim
          pkgs.vim
          pkgs.uv
          pkgs.gh
          pkgs.nixd
          pkgs.nixfmt
          pkgs.fnm
          pkgs.jujutsu
          inputs.self.packages.${pkgs.system}.lightjj
          inputs.jjui.packages.${pkgs.system}.jjui
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          pkgs.mcp-nixos
        ];

        # ------------------------------------------------------------------------
        # OpenCode Config
        # ------------------------------------------------------------------------
        xdg.configFile."opencode/opencode.jsonc".source =
          (pkgs.formats.json { }).generate "opencode.jsonc"
            opencodeSettingsForPlatform;

        # ------------------------------------------------------------------------
        # Jujutsu Config
        # ------------------------------------------------------------------------
        programs.jujutsu = {
          enable = true;
          settings = {
            user = {
              name = "Vincent-HD";
              email = "vincenthoudan@gmail.com";
            };
            ui = {
              "conflict-marker-style" = "git";
            };
            remotes.origin = {
              "auto-track-bookmarks" = "*";
            };
          };
        };

        # ------------------------------------------------------------------------
        # Shell Configuration
        # ------------------------------------------------------------------------
        # ------------------------------------------------------------------------
        # Git Configuration
        # ------------------------------------------------------------------------
        # `lib.generators.toGitINI` cannot express both `[color] branch = auto` and `[color "branch"]`
        # in one attrset, so the three `[color "..."]` blocks live in `includes` (raw snippet).
        programs.git = {
          enable = true;
          package = pkgs.git;
          ignores = [
            ".vscode/tasks.json"
            ".DS_Store"
            ".DS_Store?"
            "._*"
            ".Spotlight-V100"
            ".Trashes"
            "ehthumbs.db"
            "Thumbs.db"
            "*~"
            "*.swp"
            "*.swo"
            ".#*"
            "\\#*#"
            "*.tmp"
            "*.temp"
          ];
          includes = [
            {
              path = pkgs.writeText "git-color-subsections.ini" ''
                [color "branch"]
                  current = yellow reverse
                  local = yellow
                  remote = green

                [color "diff"]
                  meta = yellow bold
                  frag = magenta bold
                  old = red bold
                  new = green bold

                [color "status"]
                  added = yellow
                  changed = green
                  untracked = cyan
              '';
            }
          ];
          settings = {
            user = {
              name = "Vincent-HD";
              email = "vincenthoudan@gmail.com";
            };
            core = {
              editor = "code --wait";
              autocrlf = "input";
              quotepath = false;
              pager = "less -FRX";
              excludesFile = "${config.home.homeDirectory}/.config/git/ignore";
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            push = {
              default = "simple";
              followTags = true;
            };
            merge = {
              conflictstyle = "diff3";
              tool = "code";
            };
            mergetool = {
              code = {
                cmd = "code --wait $MERGED";
              };
            };
            diff = {
              tool = "code";
              algorithm = "histogram";
              renames = "copies";
            };
            difftool = {
              code = {
                cmd = "code --wait --diff $LOCAL $REMOTE";
              };
            };
            rebase = {
              autoStash = true;
              autoSquash = true;
            };
            fetch.prune = true;
            branch = {
              autoSetupMerge = "always";
              autoSetupRebase = "always";
            };
            color = {
              ui = "auto";
              branch = "auto";
              diff = "auto";
              status = "auto";
            };
            alias = {
              st = "status";
              co = "checkout";
              br = "branch";
              ci = "commit";
              unstage = "reset HEAD --";
              last = "log -1 HEAD";
              lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
              ll = "log --oneline --graph --decorate --all";
              amend = "commit --amend --no-edit";
              fix = "commit --fixup";
              squash = "commit --squash";
              wip = "commit -am \"WIP\"";
              undo = "reset HEAD~1 --mixed";
              stash-show = "stash show -p";
              find = "!git log --pretty=\"format:%Cgreen%H %Cblue%s\" --name-status --grep";
              filelog = "log -u";
              aliases = "config --get-regexp alias";
            };
            help.autocorrect = 1;
            rerere.enabled = true;
            log.date = "relative";
            grep.lineNumber = true;
            tag.sort = "version:refname";
            versionsort.suffix = [
              "-pre"
              ".pre"
              "-beta"
              ".beta"
              "-rc"
              ".rc"
            ];
          };
        };
      }

      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        # Cursor's upstream desktop file uses an icon name that KDE does not resolve here.
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

        # OpenCode headless server, started after the Linux graphical session.
        systemd.user.services.opencode-web = {
          Unit = {
            Description = "Shared OpenCode backend";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${opencode-bin} serve";
            Restart = "always";
            RestartSec = "2";
            WorkingDirectory = "%h";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        programs.bash = {
          enable = true;
          initExtra = ''
            eval "$(${pkgs.lib.getExe pkgs.fnm} env --use-on-cd --shell bash)"
          '';
        };
      })

      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        launchd.agents.opencode-web = {
          enable = true;
          config = {
            ProgramArguments = [
              opencode-bin
              "serve"
            ];
            KeepAlive = true;
            RunAtLoad = true;
            WorkingDirectory = config.home.homeDirectory;
          };
        };
      })
    ];
}
