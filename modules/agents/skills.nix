{ inputs, ... }:
{
  config.flake.modules.homeManager.agentSkills =
    {
      ...
    }:
    {
      # Portable Agent Skills: one registration → ~/.agents/skills via agentCommon.
      # Codex and Cursor discover that path natively; VS Code is pointed
      # there by agentVscode. Do not also install these under client-specific paths.
      custom.agentSetup.skills = {
        # Select only these directories from their pinned upstream source trees.
        context7-mcp = "${inputs.context7-skills}/plugins/claude/context7/skills/context7-mcp";
        # User-invoked grilling entry points and their delegated disciplines.
        grill-me = "${inputs.mattpocock-skills}/skills/productivity/grill-me";
        grill-with-docs = "${inputs.mattpocock-skills}/skills/engineering/grill-with-docs";
        # The main flow after grilling: spec, ticket breakdown, implementation, review.
        to-spec = "${inputs.mattpocock-skills}/skills/engineering/to-spec";
        to-tickets = "${inputs.mattpocock-skills}/skills/engineering/to-tickets";
        implement = "${inputs.mattpocock-skills}/skills/engineering/implement";
        code-review = "${inputs.mattpocock-skills}/skills/engineering/code-review";
        # Bootstrap the flow needs: writes the per-repo tracker and domain docs under
        # docs/agents/ that to-spec, to-tickets, and code-review read.
        setup-matt-pocock-skills = "${inputs.mattpocock-skills}/skills/engineering/setup-matt-pocock-skills";
        grilling = "${inputs.mattpocock-skills}/skills/productivity/grilling";
        domain-modeling = "${inputs.mattpocock-skills}/skills/engineering/domain-modeling";
        handoff = "${inputs.mattpocock-skills}/skills/productivity/handoff";
        research = "${inputs.mattpocock-skills}/skills/engineering/research";
        # Local snapshot of mattpocock wait-what, renamed bro for /bro. No CONTEXT.md.
        bro = ./assets/skills/bro;
        # One-shot French re-pitching with technical vocabulary kept in English.
        frr = ./assets/skills/frr;
        narrow-react-prop-types = "${inputs.humanlayer-skills}/plugins/narrow-react-prop-types/skills/narrow-react-prop-types";
        show-me = "${inputs.humanlayer-skills}/plugins/show-me/skills/show-me";
        # Day-to-day: describe @ at start; commit only when a new prompt switches concern.
        jj-auto-revise = ./assets/skills/jj-auto-revise;
        # Later: capture op id → squash blob → resplit for stacked PRs; never push from the skill.
        jj-resplit-stack = ./assets/skills/jj-resplit-stack;
        # Conflicted rebase/merge: capture op id, oldest-first jj new + squash, running count.
        jj-solve-conflict = ./assets/skills/jj-solve-conflict;
        papercuts = ./assets/skills/papercuts;
        reference-repository = ./assets/skills/reference-repository;
      };
    };
}
