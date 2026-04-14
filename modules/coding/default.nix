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
    { pkgs, config, ... }:
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
    in
    {
      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
      home.packages = [
        codeCliWrapsCursor
        (pkgs.lib.lowPrio pkgs.vscode)
        cursorPkg
        opencode-wrapper
        pkgs.neovim
        pkgs.vim
        pkgs.uv
        pkgs.nixd
        pkgs.fnm
        pkgs.jujutsu
      ];

      # ------------------------------------------------------------------------
      # OpenCode Service
      # ------------------------------------------------------------------------
      # OpenCode headless server — always running, reachable at http://localhost:4096
      # Starts after graphical-session.target so plasma-session has already run
      # `systemctl --user import-environment`, giving us the full NixOS PATH.
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
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      # ------------------------------------------------------------------------
      # OpenCode Config
      # ------------------------------------------------------------------------
      xdg.configFile."opencode/opencode.jsonc".source = ./assets/opencode.jsonc;

      # ------------------------------------------------------------------------
      # Shell Configuration
      # ------------------------------------------------------------------------
      programs.bash.enable = true;
      programs.bash.shellAliases = {
        nixos-switch = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/.nixfiles#pc-fixe";
      };
      programs.bash.initExtra = ''
        eval "$(${pkgs.lib.getExe pkgs.fnm} env --use-on-cd --shell bash)"
      '';

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
    };
}
