{ ... }:
{
  # Home Manager: direnv + nix-direnv for per-project Nix shells (.envrc / flake).
  config.flake.modules.homeManager.direnv =
    { ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        # Drop direnv's own log lines (`loading`, `using flake`, `export +VAR…`).
        # Our flake shellHook banner still prints.
        silent = true;
        config.global = {
          hide_env_diff = true;
          # Disable the "is taking a while to execute" warning during flake rebuilds.
          warn_timeout = "0s";
        };
      };
    };
}
