# T3 Code conversation migration

Research date: 2026-10-04. The local upstream checkout is `pingdotgg/t3code` at
`eac52f0087d9ba5dee5542f24788d1482affae43`. Parent verification confirms that the pinned
`0.0.46-nightly.20261004.2644` sources contain the same importer contracts and onboarding UI:
[WelcomeWizard.tsx](https://raw.githubusercontent.com/pingdotgg/t3code/v0.0.46-nightly.20261004.2644/apps/web/src/components/onboarding/WelcomeWizard.tsx),
[agentSessions RPC contracts](https://raw.githubusercontent.com/pingdotgg/t3code/v0.0.46-nightly.20261004.2644/packages/contracts/src/agentSessions.ts),
and [RPC registry](https://raw.githubusercontent.com/pingdotgg/t3code/v0.0.46-nightly.20261004.2644/packages/contracts/src/rpc.ts).

## 1. Actual import path

T3 Code has a direct Codex transcript import flow. The user-facing entry point is the first-run
**Set up T3 Code → Projects** step in the welcome wizard. It scans the selected computers, shows
project candidates, creates or reuses a T3 project for each selected directory, and imports the
recent conversations associated with that project. Existing workspaces skip this wizard, and the
reviewed source exposes no separate ongoing import screen or documented CLI import command.
[Welcome wizard docs](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/docs/user/welcome-wizard.md#L1-L82) ·
[wizard import step](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/web/src/components/onboarding/WelcomeWizard.tsx#L1135-L1342)

The UI calls an authenticated internal WebSocket RPC: `agentSessions.scan` discovers candidates and
`agentSessions.import` imports them. The import input carries a T3 `projectId` and an optional
`expectedWorkspaceRoot`; it is an application RPC contract, not evidence of a public REST endpoint.
[RPC contract](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/packages/contracts/src/rpc.ts#L1180-L1201) ·
[server dispatch](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/ws.ts#L3141-L3150)

## 2. What is imported

The scanner reads Codex transcript metadata, including the recorded `cwd` and native session ID,
then parses visible user and assistant text. The importer retains the first user prompt and up to
200 visible messages, while omitting tool activity and attachments. The UI documents additional
best-effort limits: recent conversations only, per-file and per-project scan caps, and skipping
malformed, unreadable, or over-limit records.
[scanner](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/project/AgentSessionScanner.ts) ·
[importer](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/project/AgentSessionImporter.ts#L140-L365) ·
[documented limits](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/docs/user/welcome-wizard.md#L48-L79)

This is a transcript projection plus a native-session binding, not a lossless T3 activity import.
Imported messages have no provider turn, tool, approval, checkpoint, diff, or attachment records.

## 3. Project mapping and worktrees

- The wizard creates or reuses the T3 project whose `workspaceRoot` is the selected candidate path;
  the imported thread receives that `projectId`. GitHub remote identity is used to group checkout
  candidates in the picker; it does not merge their filesystem roots.
- The imported thread is created with `branch: null` and `worktreePath: null`. Its runtime cwd is
  the selected project root, so the import does not recreate the source branch or worktree binding.
- Linked Git worktrees, T3-managed worktrees, Codex scratch directories under `Documents/Codex`,
  and `Downloads` are excluded from onboarding candidates. A conversation whose recorded cwd is in
  one of those locations will therefore not be offered by this UI flow.

[project grouping](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/web/src/onboarding/projectImport.logic.ts) ·
[scanner exclusions](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/project/AgentSessionScanner.ts#L635-L720) ·
[imported thread fields](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/project/AgentSessionImporter.ts#L270-L350)

## 4. Native continuation versus resume-only support

The importer stores the Codex native thread ID as a strong `nativeThreadRef` and seeds a Codex
`resumeCursor`. The normal Codex adapter later calls `thread/resume` with that native ID. Therefore
an imported Codex conversation can continue against its existing native Codex session; the ordinary
resume operation alone would not discover conversations, map projects, or create T3 transcript
history.
[imported resume binding](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/project/AgentSessionImporter.ts#L270-L340) ·
[Codex resume adapter](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/orchestration-v2/Adapters/CodexAdapterV2.ts#L5429-L5480)

The exact provider-side context reconstruction after the native resume call was not tested here;
the verified contract is the native ID binding and the `thread/resume` call.

## 5. Caveats for archived sessions and sidebar state

- The scanner uses transcript files and activity timestamps, not a Codex archive listing. An
  archived session can be discovered if its local transcript is present and otherwise eligible, but
  this report does not verify whether every archived Codex transcript is surfaced by the installed
  Codex version.
- The Codex adapter has an archive recovery branch: if `thread/resume` reports an archived session,
  it calls `thread/unarchive` and retries. Whether a particular old session can be unarchived still
  depends on Codex's local state and version.
- Imported app threads are initialized with `historyOrigin: "v1_import"`, `settledOverride: "settled"`,
  and no branch, worktree, pull request, pin, or active-order metadata. Expect imported threads to
  begin in the settled/sidebar history state rather than as active work; the source sets the metadata
  explicitly, but this report did not exercise the rendered sidebar.

[archive recovery](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/orchestration-v2/Adapters/CodexAdapterV2.ts#L5430-L5458) ·
[sidebar metadata](https://github.com/pingdotgg/t3code/blob/eac52f0087d9ba5dee5542f24788d1482affae43/apps/server/src/project/AgentSessionImporter.ts#L285-L350)

## Conclusion

Direct Codex migration exists, but it is an onboarding project import flow backed by internal
WebSocket RPCs. It imports a bounded visible transcript, maps it to a T3 project rooted at the
selected checkout, preserves the native Codex ID for continuation, and deliberately drops source
worktree/branch and rich runtime metadata. Existing-project users should not assume that ordinary
Codex resume support is itself an import mechanism.

## 6. ChatGPT conversations and projects

No direct ChatGPT cloud conversation importer was found: `AgentSessionSource` accepts only
`claudeAgent` and `codex`. The similarly named ChatGPT profile import transfers authentication
registrations and credentials, not messages or projects.
[accepted sources](https://github.com/pingdotgg/t3code/blob/v0.0.46-nightly.20261004.2644/packages/contracts/src/agentSessions.ts) ·
[profile schema](https://github.com/pingdotgg/t3code/blob/v0.0.46-nightly.20261004.2644/packages/contracts/src/providerSetup.ts)

ChatGPT offers a data export containing chat history. Its project model also includes shared files,
instructions and connected sources; a conversation export alone is not evidence that T3 can restore
that project structure. ChatGPT Work history is separate from Codex history.
[export documentation](https://help.openai.com/en/articles/7260999-exporting-your-chatgpt-history-and-data) ·
[projects and history](https://learn.chatgpt.com/docs/projects)

A possible indirect route is exported visible text → a new native Codex session → T3's native-session
import. `showagent` documents file/share-link conversion with an explicit working directory and a
dry-run. It carries visible user/assistant text and omits attachments, tool calls, permissions and
runtime state. Converting a whole ChatGPT export would need an adapter and explicit project mapping;
this end-to-end route has not been tested with the installed Codex/T3 versions.
[showagent web import](https://github.com/aytzey/showagent/blob/main/docs/web-import.md) ·
[compatibility evidence](https://github.com/aytzey/showagent/blob/main/docs/compatibility.md)

## Recommended next action

Inventory metadata only, separating eligible repository-root Codex sessions from excluded worktree
and Documents/Codex sessions, plus ChatGPT cloud/Work conversations. Trial one ordinary Codex project
through T3 onboarding before bulk migration. A complete migration including excluded sessions and
app-level organization requires additional import work; no conversation migration was performed by
this investigation.
