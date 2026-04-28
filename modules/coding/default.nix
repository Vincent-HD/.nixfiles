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
      # `jj-ryu` ships a Linux x64 prebuilt binary on npm. On this single-host
      # setup, install that artifact directly instead of reproducing npm's wrapper.
      # Update with:
      #   nix run github:Mic92/nix-update -- --file modules/coding/default.nix --version <new> jj-ryu
      jjRyu = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "jj-ryu";
        version = "0.0.1-alpha.11";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/jj-ryu-linux-x64/-/jj-ryu-linux-x64-${finalAttrs.version}.tgz";
          hash = "sha256-kTSS7XzS67OoVL9hGToDxHD4JUaf98i3U2H4K1i4+Qk=";
        };

        nativeBuildInputs = [ pkgs.gnutar ];
        dontUnpack = true;
        dontBuild = true;

        installPhase = ''
          tar -xzf "$src" --strip-components=1 package/ryu
          install -Dm755 ryu "$out/bin/ryu"
        '';

        meta = {
          description = "Stacked PRs for Jujutsu with GitHub/GitLab support";
          homepage = "https://github.com/dmmulroy/jj-ryu";
          license = pkgs.lib.licenses.mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "ryu";
        };
      });

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

      checkGpuVideo = pkgs.writeShellScriptBin "check-gpu-video" ''
        echo "=== GPU Video Encoder/Decoder Monitor ==="
        echo ""
        echo "=== Per-process GPU usage ==="
        nvidia-smi pmon -c 1 2>/dev/null
        echo ""
        echo "=== Encoder/decoder utilization ==="
        nvidia-smi dmon -s u -c 1 2>/dev/null
      '';
    in
    {
      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
      home.packages = [
        jjRyu
        codeCliWrapsCursor
        (pkgs.lib.lowPrio pkgs.vscode)
        cursorPkg
        opencode-wrapper
        checkGpuVideo
        pkgs.neovim
        pkgs.vim
        pkgs.uv
        pkgs.gh
        pkgs.nixd
        pkgs.nixfmt
        pkgs.fnm
        pkgs.jujutsu
        pkgs.mcp-nixos
      ];

      # Cursor's upstream desktop file uses an icon name that KDE does not resolve here.
      # Install an explicit desktop file with a direct icon path, like the CurseForge fix.
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
      # Jujutsu Config
      # ------------------------------------------------------------------------
      xdg.configFile."jj/config.toml".source = pkgs.writeText "jj-config.toml" ''
        [user]
        name = "Vincent-HD"
        email = "vincenthoudan@gmail.com"

        [ui]
        conflict-marker-style = "git"
      '';

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
