{ ... }:
{
  config.flake.modules.homeManager.agentSkills =
    {
      ...
    }:
    {
      # Portable Agent Skills: one registration → ~/.agents/skills via agentCommon.
      # Codex, Cursor, and OpenCode discover that path natively. Do not also install
      # these under ~/.cursor/skills, ~/.codex/skills, or ~/.config/opencode/skills.
      custom.agentSetup.skills = {
        context7-mcp = ./assets/skills/context7-mcp;
        grill-me = ./assets/skills/grill-me;
        # Day-to-day: meaningful jj revs; prefer absorb/squash-into over noisy new commits.
        jj-auto-revise = ./assets/skills/jj-auto-revise;
        # Later: backup → squash blob → resplit for stacked PRs; never push from the skill.
        jj-resplit-stack = ./assets/skills/jj-resplit-stack;
        papercuts = ./assets/skills/papercuts;
        reference-repository = ./assets/skills/reference-repository;
        rtk = ./assets/skills/rtk;
      };
    };
}
