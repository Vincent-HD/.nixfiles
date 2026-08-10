{ ... }:
{
  config.flake.modules.homeManager.codingGit =
    {
      pkgs,
      config,
      ...
    }:
    {
      home.packages = [ pkgs.gh ];

      # `lib.generators.toGitINI` cannot express both `[color] branch = auto`
      # and `[color "branch"]` in one attrset, so raw color subsections live in
      # `includes`.
      programs.git = {
        enable = true;
        package = pkgs.git;
        ignores = [
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
            editor = "cursor --wait";
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
            tool = "cursor";
          };
          mergetool.cursor.cmd = "cursor --wait $MERGED";
          diff = {
            tool = "cursor";
            algorithm = "histogram";
            renames = "copies";
          };
          difftool.cursor.cmd = "cursor --wait --diff $LOCAL $REMOTE";
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
