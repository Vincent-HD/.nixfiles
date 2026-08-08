{ inputs, ... }:
{
  # Home Manager: shared interactive command-line tools and shell integrations.
  config.flake.modules.homeManager.commandLine =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      fdCommand = "${pkgs.fd}/bin/fd --hidden --follow --exclude .git";
      batPreview = "${pkgs.bat}/bin/bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || true";
      irisPackage = inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      home.packages = [
        pkgs.ast-grep
        pkgs.bottom
        pkgs.carapace
        pkgs.catimg
        pkgs.choose
        pkgs.deadnix
        pkgs.doggo
        pkgs.duf
        pkgs.dua
        pkgs.eza
        pkgs.fd
        pkgs.fnm
        pkgs.glow
        pkgs.gping
        inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.hyperfine
        # IRIS provides TTY-native command suggestions on Linux and macOS.
        irisPackage
        pkgs.jaq
        pkgs.just
        pkgs.lazygit
        pkgs.nh
        pkgs.nix-output-monitor
        pkgs.nurl
        pkgs.nvd
        pkgs.onefetch
        pkgs.ouch
        pkgs.pay-respects
        pkgs.pik
        pkgs.procs
        pkgs.ripgrep
        pkgs.sad
        pkgs.sd
        pkgs.starship-jj
        pkgs.statix
        pkgs.tealdeer
        pkgs.tokei
        pkgs.vivid
        pkgs.xh
        pkgs.yq
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        pkgs.ghostty
        # GTK4 currently fails to link ripdrag on Apple Silicon macOS.
        pkgs.ripdrag
      ];

      # Install the terminal inventory separately from the Nix module logic so it can evolve as a script.
      home.file."bin/cli-tools" = {
        source = ./assets/cli-tools;
        executable = true;
      };

      # Put user-managed helper scripts and Darwin-only application CLIs on PATH.
      home.sessionPath = [
        "${config.home.homeDirectory}/bin"
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        "${config.home.homeDirectory}/Library/Application Support/JetBrains/Toolbox/scripts"
        "${config.home.homeDirectory}/.bun/bin"
      ];

      # Point nh at this flake so `nh os`, `nh darwin`, and `nh home` can default here.
      home.sessionVariables = {
        NH_FLAKE = "${config.home.homeDirectory}/.nixfiles";
      };

      xdg.configFile."ghostty/config" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        text = ''
          gtk-titlebar = false
          window-decoration = false
          window-show-tab-bar = never
        '';
      };

      programs.bat = {
        enable = true;
        config = {
          paging = "never";
          style = "plain";
        };
      };

      # Keep shared shell history search on Atuin's Ctrl+R widget.
      programs.atuin = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        flags = [ "--disable-up-arrow" ];
        settings = {
          auto_sync = false;
          enter_accept = true;
          filter_mode = "host";
          style = "compact";
        };
      };

      programs.btop = {
        enable = true;
        package = pkgs.btop.overrideAttrs (previousAttrs: {
          cmakeFlags =
            previousAttrs.cmakeFlags
            ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              "-DBTOP_GPU=OFF"
            ];
        });
      };

      programs.fastfetch.enable = true;

      # Manage language and CLI tool versions declared by each project.
      programs.mise = {
        enable = true;
        enableZshIntegration = true;
      };

      programs.fzf = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        defaultCommand = "${fdCommand} --type f";
        changeDirWidget.command = "${fdCommand} --type d";
        fileWidget.command = "${fdCommand} --type f";
        historyWidget.command = "";
        defaultOptions = [
          "--height=40%"
          "--layout=reverse"
          "--border"
          "--info=inline"
          "--preview=${lib.escapeShellArg batPreview}"
        ];
      };

      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          line-numbers = true;
          navigate = true;
          side-by-side = true;
        };
      };

      programs.starship = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        settings = {
          add_newline = true;
          command_timeout = 1000;
          scan_timeout = 20;
          custom.jj = {
            command = "${pkgs.starship-jj}/bin/starship-jj starship prompt";
            detect_folders = [ ".jj" ];
            format = "[$output]($style) ";
            ignore_timeout = true;
            style = "bold purple";
            when = "${pkgs.jujutsu}/bin/jj root --ignore-working-copy >/dev/null 2>&1";
          };
        };
      };

      programs.yazi = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        shellWrapperName = "y";
      };

      programs.zoxide = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
      };

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        shellAliases = {
          cat = "bat";
          cd = "z";
          cdg = "zi";
          df = "duf";
          du = "dua";
          find = "fd";
          grep = "rg";
          help = "tldr";
          la = "eza --all --long --git --icons=auto";
          ll = "eza --long --git --icons=auto";
          ls = "eza --icons=auto";
          lt = "eza --tree --level=2 --icons=auto";
          ping = "gping";
          pkill = "pik";
          ps = "procs";
          top = "btop";
          tree = "eza --tree --icons=auto";
        };

        initContent = lib.mkMerge [
          (lib.mkOrder 1000 (
            ''
              # Use Nix-managed helpers for shell features that Home Manager does not configure directly.
              eval "$(${pkgs.pay-respects}/bin/pay-respects zsh --alias)"
              eval "$(${pkgs.fnm}/bin/fnm env --use-on-cd --shell zsh)"
              export LS_COLORS="$(${pkgs.vivid}/bin/vivid generate catppuccin-mocha)"

              md() {
                if (( $# == 0 )); then
                  if [[ -t 1 ]]; then
                    command glow
                  else
                    command cat
                  fi
                elif [[ -t 1 ]]; then
                  command glow -p "$@"
                else
                  command bat "$@"
                fi
              }

              img() {
                if [[ -t 1 ]]; then
                  command catimg "$@"
                else
                  command cat "$@"
                fi
              }

              view() {
                if [[ ! -t 1 || $# -ne 1 || ! -f $1 ]]; then
                  command bat "$@"
                  return
                fi

                local lower="''${1:l}"
                case "$lower" in
                  (*.md|*.mdown|*.markdown|*.markdn|*.mkd)
                    command glow -p "$1"
                    ;;
                  (*.png|*.jpg|*.jpeg|*.gif)
                    command catimg "$1"
                    ;;
                  *)
                    command bat "$1"
                    ;;
                esac
              }
            ''
            + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''

              source "${config.home.homeDirectory}/.orbstack/shell/init.zsh" 2>/dev/null || :
            ''
          ))
          (lib.mkOrder 1500 ''
            # Keep IRIS resident, but let its menu be shown only on demand.
            eval "$(${irisPackage}/bin/iris init zsh)"
          '')
        ];
      };

      xdg.configFile."iris/config.toml".text = ''
        [core]
        mode = "spec"
        expand-alias = false

        [keybindings]
        # Iris has no documented disabled key value; unknown bindings do not match input,
        # so Ctrl+R is passed through to Atuin instead of toggling Iris history mode.
        toggle-mode = "disabled"

        [ai]
        enabled = true
        provider = "opencodex"
        debounce_ms = 400
        min_interval_ms = 1000

        [ai.providers.opencodex]
        inherited_from = "openai"
        endpoint = "http://127.0.0.1:10100/v1"
        model = "gpt-5.6-luna"
        timeout_ms = 3000

        [ai.providers.opencodex.extra_request_body]
        reasoning_effort = "none"
      '';
    };
}
