---
name: design-minecraft-build
description: Design precise, buildable Minecraft projects from ideas, requirements, screenshots, reference images, terrain, or existing structures. Use when an agent must choose or refine block palettes, dimensions, proportions, width, height, depth, shapes, curves, orientation, facing direction, style, symmetry, modules, rooms, circulation, lighting, detailing, mod integration, coordinate bounds, material roles, or construction stages; and when preparing a build brief that may later become a .litematic or .schem file.
---

# Design Minecraft Build

Turn an aesthetic idea into a coordinate-aware construction specification. Preserve the user's visual intent while resolving dimensions, orientation, function, block availability, and buildability.

## Route the request

- For advice or ideation, return a concise design recommendation with assumptions.
- For a construction plan, create a complete build brief and coordinate schedule.
- For a real schematic artifact, complete the brief first, then use `$create-minecraft-schematic`. Do not stop at an image, ASCII diagram, or prose plan.
- For changes to an existing build, design only the requested module and define its attachment surfaces.

## Gather only decisive context

Discover from the request, images, world files, or local modpack before asking. Resolve:

1. Java or Bedrock edition, exact game version, mods, resource pack, and survival/creative constraints.
2. Deliverable: ideas, build brief, block-by-block plan, material estimate, `.litematic`, `.schem`, or a combination.
3. Site envelope and fixed interfaces: available width, height, depth, terrain, doors, roads, pipes, adjacent rooms, and protected blocks.
4. Front direction, world axes, origin, symmetry axis, and paste/build direction.
5. Style references, functional spaces, must-have features, forbidden blocks, and desired complexity.

Ask only when a missing answer materially changes the result. Otherwise make a coherent estimate and record it under `assumptions`.

## Analyze visual references

- Separate observable facts from estimates.
- Identify silhouette, dominant mass, secondary masses, openings, rhythm, color distribution, depth layers, lighting, and repeated motifs.
- Infer scale from known Minecraft blocks, doors, players, rails, or chunk boundaries when visible.
- Do not claim exact measurements from a perspective screenshot without a reliable scale.
- Design the requested module in relation to the existing structure; avoid rebuilding unrelated surroundings.

## Define the coordinate system first

Prefer:

- origin: front-left-bottom;
- `+X`: right when viewed from the front;
- `+Y`: upward;
- `+Z`: into the build;
- front exterior: `-Z`.

State any different convention explicitly. Give every major zone and feature an inclusive bounding box `[x1,y1,z1,x2,y2,z2]`.

## Design in layers

1. Set the envelope and reserve integration clearances.
2. Choose the primary silhouette and proportion ratios.
3. Split the mass into functional zones and circulation paths.
4. Add openings and transitions before decoration.
5. Add structural rhythm, depth, and secondary forms.
6. Assign a palette by role: structure, surface, shadow, trim, accent, light, glass, utility, machinery, and optional weathering.
7. Add high-frequency detail last. Keep large builds readable from their normal viewing distance.
8. Check player clearance, stairs, doors, maintenance access, redstone/Create movement envelopes, fluids, lighting, and mob-proofing as applicable.

Read [`references/design-heuristics.md`](references/design-heuristics.md) for proportion, curve, palette, depth, and direction heuristics.

## Produce a build brief

Use the JSON shape in [`references/build-brief-schema.md`](references/build-brief-schema.md). Copy [`assets/build-brief-template.json`](assets/build-brief-template.json) when a machine-readable artifact is useful.

Validate it:

```bash
python scripts/validate_build_brief.py build-brief.json
```

Treat this as schema and bounds validation. It does not prove that every block ID exists in the selected game registry, that an arbitrary curve schedule is geometrically correct, or that the build fits unseen terrain; verify those separately when relevant.

The brief must make these decisions explicit:

- target edition/version/mods and deliverable;
- dimensions and coordinate convention;
- front, entrances, flow direction, and symmetry;
- style keywords and reference observations;
- palette roles with exact block IDs when known;
- zones, features, and attachment interfaces with coordinates;
- assumptions, constraints, construction stages, and acceptance checks.

## Select blocks responsibly

- Choose blocks for role and texture scale, not color alone.
- Keep the main palette compact; reserve saturated colors and emissives for hierarchy.
- Verify modded registry IDs in the exact mod version before promising a schematic.
- Offer replacements when the user lacks a block or when a block entity would complicate copying.
- Distinguish decorative machinery from functional Create/redstone systems.

## Hand off to schematic generation

When the user requests `.litematic` or `.schem`:

1. Validate the build brief.
2. Convert zones/features into exact block placements or a procedural geometry generator.
3. Invoke `$create-minecraft-schematic` and follow its NBT and compatibility validation workflow.
4. Deliver both the design summary and actual downloadable artifact.

Do not describe an ungenerated file as complete.
