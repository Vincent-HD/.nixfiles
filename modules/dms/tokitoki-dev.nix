_: {
  # Home Manager: run a rebuild against the local Tokitoki checkout.
  #
  # 'programs.tokitoki.package' comes from the 'tokitoki' flake input. A variable
  # cannot drive it on its own: flake inputs resolve in pure mode, where
  # 'builtins.getEnv' returns "" (an environment-aware flake would need
  # --impure), and 'nh' reads no variable for --override-input. So 'nrs' is just
  # 'nh os switch' with the input repointed, which keeps the evaluation pure and
  # leaves flake.lock untouched:
  #
  #   TOKITOKI_DEV=1 nrs              # ~/lab/tokitoki
  #   TOKITOKI_DEV=/other/checkout nrs
  #   nrs                             # pinned github revision
  config.flake.modules.homeManager.tokitokiDev = _: {
    programs.zsh.initContent = ''
      nrs() {
        local src="$TOKITOKI_DEV"
        [[ $src == 1 ]] && src="$HOME/lab/tokitoki"
        [[ $src == 0 ]] && src=""
        [[ -n $src ]] && set -- --override-input tokitoki "path:$src" "$@"
        nh os switch "$@"
      }
    '';
  };
}
