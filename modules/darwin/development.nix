{ ... }:
{
  config.flake.modules.homeManager.darwinDevelopment =
    { pkgs, config, ... }:
    {
      home.packages = [
        pkgs.gh
        pkgs.jujutsu
        pkgs.neovim
        pkgs.nixd
        pkgs.nixfmt
        pkgs.uv
        pkgs.vim
      ];

      home.sessionPath = [
        "${config.home.homeDirectory}/Library/Application Support/JetBrains/Toolbox/scripts"
        "${config.home.homeDirectory}/.bun/bin"
      ];

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;

        shellAliases = {
          brun = "pnpm -F backend exec doppler run -- pnpm";
          frun = "pnpm -F frontend exec doppler run -- pnpm";
          wdev = "pnpm -F backend exec doppler run -- pnpm dev";
          wddev = "pnpm -F backend exec doppler run -- pnpm dev:debug";
          wgen = "pnpm -F backend exec doppler run -- pnpm codegen";
          wfb = "pnpm -F backend -F frontend --parallel exec doppler run -- pnpm dev";
          wformat = "pnpm -r lint && pnpm -r format";
          nixswitch = "sudo darwin-rebuild switch --flake ${config.home.homeDirectory}/.nixfiles#macbook-pro";
        };

        initContent = ''
          eval "$(${pkgs.lib.getExe pkgs.fnm} env --use-on-cd --shell zsh)"
          source "${config.home.homeDirectory}/.orbstack/shell/init.zsh" 2>/dev/null || :
        '';
      };

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
          mergetool.code.cmd = "code --wait $MERGED";
          diff = {
            tool = "code";
            algorithm = "histogram";
            renames = "copies";
          };
          difftool.code.cmd = "code --wait --diff $LOCAL $REMOTE";
          rebase = {
            autoStash = true;
            autoSquash = true;
          };
          fetch.prune = true;
          branch = {
            autoSetupMerge = "always";
            autoSetupRebase = "always";
          };
          color.ui = "auto";
          alias = {
            st = "status";
            co = "checkout";
            br = "branch";
            ci = "commit";
            unstage = "reset HEAD --";
            last = "log -1 HEAD";
            ll = "log --oneline --graph --decorate --all";
            amend = "commit --amend --no-edit";
            fix = "commit --fixup";
            squash = "commit --squash";
            undo = "reset HEAD~1 --mixed";
          };
          help.autocorrect = 1;
          rerere.enabled = true;
          log.date = "relative";
          grep.lineNumber = true;
          tag.sort = "version:refname";
        };
      };

      programs.jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Vincent-HD";
            email = "vincenthoudan@gmail.com";
          };
          ui."conflict-marker-style" = "git";
          remotes.origin."auto-track-bookmarks" = "*";
        };
      };
    };
}
