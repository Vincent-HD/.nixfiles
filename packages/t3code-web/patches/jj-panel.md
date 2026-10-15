# Jujutsu panel feature contract

## Purpose and placement

Bring a compact jj-view-style working-copy/revision view into T3 Code so the user can
inspect current work, redistribute changes and manage a revision stack without leaving
the conversation. Keep the horizontal list layout instead of a full history graph.
The `Jujutsu` tab is opened through the chat's right-panel add menu.

## Required behavior

- Use compact horizontal revision rows rather than large cards or permanent textareas.
- Show the current working copy and up to ten preceding revisions. Initially expand
  only the working copy; clicking an older row reveals its changed files.
- Show descriptions and file status; open description editors and revision metadata
  on demand. Include copyable commit/change IDs, authors, timestamps, bookmarks/tags
  and explicit conflict indicators identifying the affected revisions/files.
  Expanding a row shows its files; full IDs, author/committer, bookmarks/tags and the
  full description appear only through the dropdown's Show revision details action.
  Provide quick revision buttons for Absorb, Abandon, Squash into ancestor and Squash
  into parent, with the remaining actions in the dropdown. File rows expose Restore,
  Squash into ancestor and Squash into parent. These controls appear on hover and
  keyboard focus, and always open the existing confirmation dialog. Whole-revision
  shortcuts ignore file selection; a file shortcut uses checked files if its row is
  checked, otherwise just that file. Ancestor pickers include only loaded eligible
  ancestors; parent shortcuts preselect the sole eligible direct parent, or require
  choosing one when a merge has multiple eligible parents.
  Conflicts are informational: do not add a conflict resolver or merge editor.
  Preserve unsaved drafts during refresh and diff/tab navigation, scoped to the actual
  environment and workspace. Identify stale drafts before overwriting work.
  Keep other loaded revisions, including duplicated siblings, available as action
  sources through a separate collapsed list without changing the main ancestor list.
- Clicking a changed file opens T3 Code's existing DiffPanel and diff renderer with
  that jj revision/file selected. Do not implement a second diff viewer. Reads must
  also work for immutable revisions and pure jj workspaces, through the actual environment.
- Support New, Commit (describe current work then start an empty revision), Edit
  (resume an existing revision), and insertion before/after selected revisions.
- Support whole-revision and selected-file squash into an existing revision, Squash
  Onto a new revision above the destination, and Absorb into eligible ancestors.
- Support revision/branch rebase, duplicate, merge, abandon, and restoring selected
  files or all changes. Show source, destination and affected paths before confirmation.
- Provide explicit operation-aware Undo/Redo. Preserve the protected receipt-based
  undo path; do not silently revert unrelated operations using an old receipt.
- Manage local bookmarks (set/move/delete/advance). Publication must be a deliberate
  action with a visible remote/bookmark/base summary; support a single revision or
  linear stack and reuse T3's forge and PR/review integrations for status, comments,
  replies and resolution. Do not duplicate authentication or review editors.
- Use the thread's actual workspace on its environment/server. Never initialize a jj
  repository automatically. Never publish, create PRs or send review comments as a
  side effect of opening, refreshing or editing local revisions.
- Keep server-side permission checks, immutable/conflict restrictions and operation-ID
  checks. A refresh or concurrent external jj action must not permit a stale mutation.
  Receipt-based undo must not revert unrelated later operations. General Undo/Redo
  requires its own explicit confirmation against the latest displayed operation.
- Show useful missing-jj/non-repository/error states, rather than breaking the chat.
- Preserve tab persistence, keyboard handling and reopen-closed-tab behavior.

The user approved A3, A4, B2–B5, C1, C2, C4, C5, D1–D6 and E1–E4 on 2026-10-14
using the identifiers in [the source inventory](../../../docs/JJ_VIEW_FEATURES.md)
and the parent thread's selection UI.
The full graph, hunk/line transfer, historical file editing, comparison picker,
workspace management and automatic refresh watcher are outside this selection.
The usage patch is not a dependency.

## Operation and publication boundaries

`Rebase branch` means the selected revision plus its descendants (`jj rebase --source`),
matching JJ View's default drag action. It does not move the selected revision's ancestors
using jj's separate `--branch` option. Revision mode uses `--revision`.

Single and linear-stack PR/MR publication use the native GitHub/GitLab adapters and their
existing credentials. Every published revision needs an explicit local bookmark and
description; a linear stack must be fully loaded and contiguous. Preview validates the
remote destination, existing requests and bases before any push. A mismatched existing
base requires retargeting in the forge: T3's current provider port cannot retarget it.
GitLab publication is restricted to the checkout's default forge remote because its
native creation adapter does not honor an arbitrary destination context. Review links
open T3's existing PR panel, including its comment/reply/resolution controls.

Publish errors after a successful push must report partial completion and the failing
bookmark. A local Undo cannot reverse a remote push or PR/MR creation. Never advertise
an undo receipt for publication. CLI compatibility is checked with jj 0.45.1; Squash
Onto depends on jj's experimental `--onto` option.

## Integration and verification

In upstream source, inspect `apps/web/src/components/jj/JjPanel.tsx` and
`jj-panel-state.ts`, right-panel/tab stores and `ChatView.tsx`; server behavior lives
in `apps/server/src/jj/JjPanelService.ts`. Shared RPC contracts live in
`packages/contracts/src/jj.ts`, with environment-aware client state in
`packages/client-runtime/src/state/jj.ts`. Keep RPC registration, authorization,
instrumentation and capability reporting consistent when upstream APIs move.

Diff integration lives in the existing `DiffPanel.tsx` and `diffPanelStore.ts`.
File clicks carry the displayed workspace identity and operation ID; persisting/retrying
a diff must never silently replace that pin with a newer snapshot. Diff reads require
filesystem-read permission. New action, diff and forge calls are gated by their separate
environment capabilities so older patched servers keep their original panel behavior.
Forge behavior lives in `JjForgeService.ts`, `jj-forge.ts` and the JJ forge section; reuse
the application-owned source-control and pull-request service layers.

Existing tests include server `JjPanelService.test.ts`, web `jj-panel-state.test.ts`,
right-panel/store/reopen tests, contracts `jj.test.ts` and `environment.test.ts`, and
client-runtime `commandPermissions.test.ts`. Server tests exercise actual temporary jj
repositories; keep mutation safeguards covered when repairing the service.
The expanded panel also has `jj-forge.test.ts`, `JjForgeService.test.ts`,
`jj-forge-state.test.ts` and diff-selection tests in `diffPanelStore.test.ts`.

Manual acceptance: use a disposable jj workspace, open the panel, verify working-copy
plus ten ancestor rows and expansion defaults, revision metadata/conflict labels,
existing T3 diff navigation, creation/resumption/insertion, selected-file movement,
history actions, bookmarks and undo/redo. Use a local disposable remote to test push;
never create PRs, publish branches or send review messages during automated validation.
Also perform an external jj action between refresh and mutation to check stale-state
handling. Never use the user's real working copy for mutation tests.
