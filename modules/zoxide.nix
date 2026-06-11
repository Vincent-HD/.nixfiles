{ ... }:
{
  config.flake.modules.homeManager.zoxide =
    { ... }:
    {
      programs.zoxide = {
        enable = true;

        # Keep shell integration in the existing user-managed shell files until
        # shell configuration is migrated as its own ownership boundary.
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
        enableZshIntegration = false;
      };
    };
}
