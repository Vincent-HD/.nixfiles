# Temporary conversations feature contract

## Purpose and scope

Let the user mark a draft or existing conversation as temporary, then confirm before
leaving it. Reuse T3's normal thread lifecycle and deletion, without deleting the
project, worktree, or files created by the agent in the workspace.

## Required behavior

- Provide actions to mark a draft or thread temporary and to make it permanent again.
  Carry the marker from the draft through promotion to a server thread.
- When navigating away within the app, ask the user to stay or leave and discard.
  Await the existing deletion path before completing the intended navigation. Keep
  the current route and show an error when deletion fails. Avoid a duplicate prompt
  or fallback navigation that overrides the intended destination.
- Release draft and known UI state, and use existing server cleanup of linked resources.
  Do not delete a worktree, even if automatic worktree cleanup is enabled.
- Block discarding while a send is being submitted. Multiple-model sends are unavailable
  for temporary conversations because they create independently persistent threads.
- A refresh or window close may show the browser's native warning. Async deletion on
  unload is not reliable, so the conversation remains available if the window closes.
- The marker is local to the browser profile. Connected clients receive the normal
  thread deletion, but another profile cannot see or enforce the temporary marker.
- Thread deletion removes it from the visible history, but is not a full data purge:
  T3 event records, provider transcripts, remote copies, and other files can remain.
  This feature must not promise privacy or secure erasure.

## Integration and verification

Inspect `TemporaryConversationCoordinator.tsx`, `temporaryConversationNavigation.ts`,
`ThreadRouteView.tsx`, `uiStateStore.ts`, and `useThreadActions.ts` under
`apps/web/src/`. The header and thread action menus expose the toggle.

Focused tests cover navigation decisions and errors, draft promotion and marker state,
thread-action permissions, menu availability, and confirmation dialog behavior. Check
that the patch applies with neither, either, and both existing patches using `--fuzz=0`.
For manual acceptance, mark a new draft and an existing conversation temporary, try
Stay and Leave, confirm that the selected destination is preserved, check the regular
thread delete flow, and verify a worktree is retained. UI acceptance requires an
isolated app or explicit consent to interact with the installed application.
