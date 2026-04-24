{ ... }:
{
  # Home Manager: ONLYOFFICE desktop editors
  config.flake.modules.homeManager.onlyoffice =
    { ... }:
    {
      programs.onlyoffice.enable = true;
    };
}
