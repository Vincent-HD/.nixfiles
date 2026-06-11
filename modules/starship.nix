{ ... }:
{
  config.flake.modules.homeManager.starship =
    { ... }:
    {
      programs.starship = {
        enable = true;

        # Keep shell integration in the existing user-managed shell files until
        # shell configuration is migrated as its own ownership boundary.
        enableBashIntegration = false;
        enableZshIntegration = false;
      };
    };
}
