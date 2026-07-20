{ ... }:
{
  config.flake.modules.homeManager.agentSkills =
    {
      ...
    }:
    {
      # Add a portable skill here once; all three agents discover the same directory.
      custom.agentSetup.skills = {
        context7-mcp = ./assets/skills/context7-mcp;
        grill-me = ./assets/skills/grill-me;
        papercuts = ./assets/skills/papercuts;
        reference-repository = ./assets/skills/reference-repository;
        rtk = ./assets/skills/rtk;
      };
    };
}
