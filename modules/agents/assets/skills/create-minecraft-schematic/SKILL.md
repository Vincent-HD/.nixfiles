---
name: create-minecraft-schematic
description: Create, inspect, and validate real Minecraft Java schematic artifacts in .litematic and .schem formats. Use when an agent must turn a build idea, coordinate plan, block list, reference image, or generated voxel model into a downloadable Litematica or WorldEdit file; when repairing or auditing schematic NBT; or when checking dimensions, palettes, modded block states, DataVersion, compression, and format compatibility. Do not use for blueprint images alone or Bedrock structure files.
---

# Create Minecraft Schematic

Produce a real, reloadable Minecraft Java artifact. Treat an image, ASCII plan, or prose-only answer as insufficient whenever the user asks for a schematic file.

## Workflow

1. Establish the target before encoding:
   - Confirm Java Edition, Minecraft version, mod loader/modpack, desired format, placement direction, and intended air-paste behavior.
   - Prefer `.litematic` when no format is specified. Also emit `.schem` when WorldEdit compatibility is useful.
   - If the game version is absent, select a defensible version, state the assumption, and record the exact Minecraft `DataVersion`.
2. Inspect supplied references. Estimate dimensions only when scale cannot be measured; label estimates explicitly.
3. Define a single coordinate convention. Prefer `X=width`, `Y=height`, `Z=depth`, origin at front-left-bottom, front facing `-Z`.
4. Create a feature schedule before placing blocks: envelope, shells, openings, transitions, circulation, machinery, decoration, lighting, and integration surfaces.
5. Define the palette by role. Verify every modded namespace and full block state against the installed mod JAR or an authoritative source. Never invent a modded block ID.
6. Build the model deterministically as coordinates, boxes, lines, or code-generated placements. Make later placements intentionally override earlier ones.
7. Generate and validate the artifacts. Deliver the actual files, a validation report, dimensions, palette summary, assumptions, dependencies, and import instructions.

## Choose the encoding path

Use [`scripts/schematic_tool.py`](scripts/schematic_tool.py) for single-region models expressible as JSON operations. Read [`references/spec-schema.md`](references/spec-schema.md) before authoring the JSON.

For procedural curves, domes, terrain, complex symmetry, or thousands of calculated details, write a task-specific Python generator that produces the same JSON schema, then pass it to `schematic_tool.py`. Keep geometry generation separate from NBT serialization.

Install the known-good Python dependencies from `scripts/requirements.txt` into a local environment or target folder. Check current releases first; use the pins when reproducibility matters. In Codex desktop, call `load_workspace_dependencies` and prefer its bundled Python runtime; a newer system Python can lack native libraries required by NumPy/Litemapy. Outside Codex, use a supported, self-consistent Python environment rather than assuming the system interpreter is usable.

Example:

```bash
python scripts/schematic_tool.py generate build.json --output-dir outputs
python scripts/schematic_tool.py validate --spec build.json \
  --litematic outputs/build.litematic --schem outputs/build.schem
```

## Model correctly

- Keep all coordinates inside the declared region. Do not silently resize around sparse blocks.
- Use complete block-state properties for directional, multipart, powered, waterlogged, slab, stair, door, Create, or other stateful blocks.
- Use block entities only with a format writer that preserves their NBT. The bundled JSON tool intentionally rejects block-entity payloads.
- Preserve air in the region volume. Explain whether WorldEdit should paste with `-a`.
- Keep modded blocks only when the target instance contains the matching mod and version. Provide a vanilla fallback only when the user wants one.
- Avoid legacy `.schematic` unless explicitly requested for an old toolchain.

## Validate before delivery

Read [`references/formats-and-validation.md`](references/formats-and-validation.md) when selecting a format, troubleshooting a loader, or reporting compatibility.

Require all applicable checks:

- gzip and raw NBT parse succeed;
- declared dimensions equal reloaded dimensions;
- palette entries are unique and every referenced index is in range;
- decoded block-array length equals `width × height × depth`;
- non-air block count and selected landmark coordinates match the source model;
- Litematic metadata, region count, version, subversion, and `MinecraftDataVersion` are coherent;
- Sponge `Version`, `DataVersion`, dimensions, palette, VarInt stream, entities, and block entities are coherent;
- an independent library reload succeeds when available;
- file hashes and byte sizes are recorded after the final regeneration.

If Minecraft/Litematica/WorldEdit cannot be launched, report library-level structural validation precisely. Do not claim an in-game test that did not happen.

## Deliver

Return clickable links to the `.litematic` and/or `.schem`, not a preview in their place. Include:

- target Minecraft version and required mods;
- dimensions and orientation;
- non-air count and palette highlights;
- assumptions made from images or missing measurements;
- validation method and any untested runtime condition;
- concise Litematica and WorldEdit import steps.
