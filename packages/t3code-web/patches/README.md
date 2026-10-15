# Local T3 Code patches

These documents describe product intent for a human or LLM repairing upstream drift.
The `.patch` files record implementation; the feature contracts explain what must survive.
Keep local code comments for non-obvious implementation reasons, rather than repeating
these contracts throughout upstream source.

| Patch | Feature contract | Build output | Host option |
| --- | --- | --- | --- |
| `composer-usage.patch` | [Usage statistics](composer-usage.md) | Web renderer | `custom.t3code.enableUsagePatch` |
| `jj-panel.patch` | [Jujutsu panel](jj-panel.md) | Web renderer and server | `custom.t3code.enableJjPanel` |

Current patch base: upstream tag `v0.0.46-nightly.20261015.3158`, commit
`e6bbfdb9ffe8334bed1c9b992f828f04d30db7ea`. This records the base actually reviewed
for these patches; a package pin bump alone does not establish a new reviewed base.
Update this record after adapting the patches to a new source version.

At this base, preserve the composer's project-scoped model picker and upstream's
stable callback wrappers. JJ diff selection must bypass the single Git preview query;
do not restore the removed environment-cwd fallback. Effect's crypto UUID generator
is now a method, and forge provider kinds use upstream's branded constructors.
Honor the forge provider's `headBranchProbe` selectors and lookup limits while
retaining the JJ publication destination checks.

## Repair workflow

1. Read the affected feature contract and the actual upstream code at the package pin.
   Diagnose whether the failure is patch context drift, a renamed API, missing provider
   data, or a behavioral regression. Preserve intent rather than forcing old code back in.
2. Use a clean temporary checkout at that pin. Preserve any existing dirty authoring
   checkout. Both patches must apply independently; the combined build applies usage
   first, then JJ. Both touch `ChatView.tsx`, so inspect that integration explicitly.
3. Adapt the feature, regenerate its source patch, and retain `--fuzz=0`. Exact context
   can move within a file; zero fuzz forbids ignoring context lines, not line offsets.
   A clean application alone does not prove behavioral correctness.
4. Run the affected existing tests listed in the feature contract and relevant focused
   lint/typecheck commands from upstream's `AGENTS.md`. Test commands run in the patched
   upstream source checkout, not this Nix repository. Report what actually ran.
5. Build the affected package when packaging or compilation changed. Available outputs
   are `t3code-usage`, `t3code-jj`, and `t3code-patched` (both). Keep testing/building an
   explicit maintenance step; no automatic candidate gate is installed. UI acceptance
   still needs a manual check in the installed app or an authorized isolated dev app.

Nix rebuilds selected JavaScript outputs and repacks the matching upstream AppImage.
The upstream Electron/native modules remain the packaging base. Keep desktop and source
versions aligned; dependency/native-module changes require reviewing this boundary.
Do not run development servers against live `~/.t3/userdata` or restart the app hosting
the active conversation as part of a test.

To isolate a failure, disable that feature's host option and switch again. Disabling
both selects the original upstream AppImage. Never silently drop an enabled patch.
Binary rollback does not reverse database migrations; retain the state backup guidance
in [UPDATE_COMMANDS.md](../../../docs/UPDATE_COMMANDS.md).
