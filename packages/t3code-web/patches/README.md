# Local T3 Code patches

These documents describe product intent for a human or LLM repairing upstream drift.
The `.patch` files record implementation; the feature contracts explain what must survive.
Keep local code comments for non-obvious implementation reasons, rather than repeating
these contracts throughout upstream source.

| Patch | Feature contract | Build output | Host option |
| --- | --- | --- | --- |
| `composer-usage.patch` | [Usage statistics](composer-usage.md) | Web renderer and server | `custom.t3code.enableUsagePatch` |
| `jj-panel.patch` | [Jujutsu panel](jj-panel.md) | Web renderer and server | `custom.t3code.enableJjPanel` |
| `temporary-threads.patch` | [Temporary conversations](temporary-threads.md) | Web renderer | `custom.t3code.enableTemporaryThreads` |

Current patch base: upstream tag `v0.1.2-nightly.20261022.3541`, commit
`044f07257c9684ae4543bd1e1ebf9c394e9e3830`. This records the base actually reviewed
for these patches; a package pin bump alone does not establish a new reviewed base.
Update this record after adapting the patches to a new source version.

At this base, keep `useUsageLimitsPanel` and add composer accounts beside it; do not
restore the inlined limits panel. Do not wrap those ChatView values in `useMemo` or
`useCallback`: manual memoization bails the React Compiler out of `ChatView`, and its
existing render-phase state adjustments then loop (minified React error 301). The response usage chip lives in
`TimelineAssistantRows.tsx`. Cursor account usage still goes through
`cursorTurnTokenUsage`, alongside upstream `cursorContextWindowTokens`. Mount the
Jujutsu panel from `RightPanelSurfaceContent` and keep open/diff actions in
`useRightPanelActions`. A selected JJ revision must bypass the Git preview query.
Right-panel shortcut coverage is `surfaceShortcutActionForKey`; the old keyboard
component test is gone. Effect's crypto UUID generator is a method, and forge
provider kinds use upstream's branded constructors. Honor `headBranchProbe`
selectors and lookup limits while retaining the JJ publication destination checks.
Bare-repository assertions go through `git --git-dir`, because `VcsProcess` sets
`safe.bareRepository=explicit`.

## Repair workflow

1. Read the affected feature contract and the actual upstream code at the package pin.
   Diagnose whether the failure is patch context drift, a renamed API, missing provider
   data, or a behavioral regression. Preserve intent rather than forcing old code back in.
2. Use a clean temporary checkout at that pin. Preserve any existing dirty authoring
   checkout. The patches must apply independently; the combined build applies usage,
   then JJ, then temporary conversations. Inspect their shared integration points.
3. Adapt the feature, regenerate its source patch, and retain `--fuzz=0`. Exact context
   can move within a file; zero fuzz forbids ignoring context lines, not line offsets.
   A clean application alone does not prove behavioral correctness.
4. Run the affected existing tests listed in the feature contract and relevant focused
   lint/typecheck commands from upstream's `AGENTS.md`. Test commands run in the patched
   upstream source checkout, not this Nix repository. Report what actually ran.
5. Build the affected package when packaging or compilation changed. Available outputs
   include `t3code-usage`, `t3code-jj`, `t3code-temporary`, `t3code-patched` (usage and JJ),
   and `t3code-all`. Keep testing/building an
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
