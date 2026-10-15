# JJ View feature inventory and comparison with the T3 Jujutsu panel

Research date: 2026-10-13. The comparisons below describe the panel before expansion.
On 2026-10-14 the user selected A3, A4, B2–B5, C1, C2, C4, C5, D1–D6 and E1–E4.
See the [current feature contract][t3-contract] for the resulting scope and limitations.

## Scope and evidence

The primary source is the read-only clone at `/home/vincent/.references/jj-view`, inspected at **`f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51`** (commit dated 2026-10-08). Its [manifest][manifest] reports **2.10.0**. This inventory describes that supplied main snapshot; it does not claim that the moving upstream main branch still has the same head. The clone's `AGENTS.md` was read first.

Features below were traced from the [README][readme] to [manifest commands and menus][manifest], [VS Code command registration][registration], and their command handlers or graph message handlers. Graph gestures count as UI support even when they have no separate command-palette entry. A callable CLI method alone does not count. “Implemented” means a connected source-code path was found, not that it was exercised in a running extension.

The comparison uses the actual local [T3 patch][t3-patch] and [feature contract][t3-contract], not the older feasibility note. The patch guide records upstream base `ec80933ac8cd02fec5c97b342462ccc9567cdb1e`. Local patch files contain uncommitted work, so an upstream commit permalink cannot represent their current contents. SHA-256 values at inspection:

```text
jj-panel.patch  a4553c41c730fcd8f1e250c239bad2362c3d6bb616402552152bbc3286a4e180
jj-panel.md     a50d8e3b600c6c29b00f0075adb363ed4992e04194e2945b06c7b223492918a4
```

T3 statuses mean **Present** for the listed capability, **Partial** for a narrower equivalent, and **Missing** for no connected UI in this patch. These are comparisons with the custom Jujutsu panel, not claims about every other T3 surface or its orchestration tools. Missing features are options for discussion, not contract failures or a proposed implementation backlog.

## Source inventory mapped to selection IDs

IDs match the French collapsible selection UI in the parent T3 thread. This evidence document groups details differently: repeated IDs are variants of the same selectable feature, and A4 / A5 separates single-file from multi-file diffs. F3 in that UI groups graph gestures and multi-selection covered under A2 here; F4 groups description formatting plus VS Code appearance, shortcuts, decorations and process-monitor tooling verified in the manifest and registration. Every row is an implemented JJ View VS Code feature at the inspection commit, subject to the qualifications below. Selection happened after this inventory was written.

### Inspect and describe work

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| A1 | Working copy and changed files | SCM shows current work and bounded ancestor groups, file statuses and conflict resources. [SCM model][scm-model], [file actions][resource-state]. | **Present:** compact rows for `@` and up to ten ancestors, current files initially expanded, older rows expandable, status letters and file icons. |
| A2 | Interactive history graph | Commit selection opens details; Ctrl/Cmd-click selects multiple revisions; Escape clears selection. Graph supports parallel lanes, hidden/ghost nodes, divergent styling, workspace pills and configurable colors. [Graph UI][graph-app], [nodes][graph-nodes], [layout][graph-layout]. | **Missing:** the bounded list has no graph, graph selection, drag-and-drop, divergent styling or lane themes. |
| A3 | Revision details | Description, files, author/committer, timestamps, immutable/empty/conflict flags, tags/bookmarks and copyable IDs. [Details UI][details-ui]. | **Partial:** descriptions, file lists, shortened change IDs and immutable/conflict labels; no dedicated details view, author/time display, tags/bookmarks or copy-ID action. The schema carries empty/parent information without providing the complete details UI. |
| B1 | Set descriptions without finishing work | SCM input, interactive prompt and details editor update the chosen revision's description. [Describe][describe], [details controller][details-controller]. | **Present:** on-demand editors for visible mutable revisions, drafts retained on refresh, stale drafts identified before saving. This edits the message; it is not JJ View's **Edit** action. |
| F4 | Format description body | Format action, configurable title/body rulers, optional wrapping on save. [Details UI][details-ui], [settings][manifest]. | **Missing:** plain description textarea and save/cancel. |
| A7 | Refresh after external changes | File watching or polling, operation-store watching and focus changes refresh SCM/log state. [Change detection][change-detection]. | **Partial:** refresh on opening, focus/visibility changes, after mutations and via Refresh; no continuous watcher/polling while the panel remains focused. |

### Start, finish or resume a revision

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| B2 | New / New Child | Creates an empty revision and switches the working copy to it. SCM defaults to current work; graph New Child uses the selected revision as parent. It does not set the old revision's description. [New command][new], [parent payload][new-payload], [graph actions][graph-app]. | **Missing.** |
| B3 | Commit | Uses the SCM description, describes the current working-copy revision and creates its next empty working copy. Commit Prompt asks for the description first. [Commit][commit], [prompt][commit-prompt], [CLI calls][describe-commit-service]. | **Missing:** Save only describes; it does not create the next revision. |
| B4 | Edit an existing revision | Makes a selected existing revision the working-copy revision. This resumes its content rather than creating another revision or merely editing its message. [Edit][edit], [CLI call][edit-service]. | **Missing:** the pencil button is a description editor. |
| B5 | New Before / New After | Inserts a new revision before or after the selected revision(s), rather than just creating an unrelated child. [Before][new-before], [after][new-after], [CLI calls][new-service]. | **Missing.** |

### Redistribute or discard changes

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| C1 | Squash into parent / ancestor / graph target | Transfers a revision's changes into an existing destination. SCM offers parent or chosen mutable ancestor; graph drag with S uses the hovered target. An emptied source is normally abandoned. [Squash workflow][squash-command], [graph dispatch][graph-dispatch], [CLI modes][squash-service]. | **Partial:** whole `@` only, into a visible mutable non-conflicted ancestor. Explicit confirmation; keep destination description by default or replace it, including with empty text. No older-source squash or arbitrary graph target. |
| C5 | Squash Onto | Shift+S drag transfers source changes into a **new** revision on top of the target. It leaves the target itself unchanged and normally empties/abandons the source. It is distinct from Squash Into and from copying the source. [Drag modes][drag-modes], [graph dispatch][graph-dispatch], [CLI modes][squash-service]. | **Missing.** |
| C4 | Absorb | Revision/SCM action asks jj to assign eligible edits to the mutable ancestors that introduced the affected lines, without choosing one destination. Changes jj cannot assign can remain in the source. [Absorb command][absorb], [CLI call][absorb-service]. | **Missing.** |
| C2 | Squash selected files | SCM file selection can transfer one or more files' changes into a parent, chosen mutable ancestor or child, preserving the destination description. Child choice is prompted when there are multiple children. [File menus][manifest], [file handlers][squash-files]. | **Missing:** listed files have no per-file action; whole-source squash always moves all changes. |
| C3 | Squash a hunk or selected lines | Diff hunk action or editor selection transfers only that block/selection into the parent. [Menus][manifest], [selection handlers][squash-selection], [partial squash][partial-squash-service]. | **Missing.** |
| D5 | Restore selected files / discard a diff hunk | Restore resets selected working-copy files, or removes their changes from a specified older revision. Discard Change operates on one diff hunk. [Restore][restore], [restore flags][restore-service], [hunk discard][discard]. | **Missing.** |
| D6 | Undo / Redo | Graph buttons and registered commands invoke jj's last-operation undo/redo. [Registration][registration], [CLI calls][undo-service]. | **Partial:** receipt-checked undo of this panel's latest applicable action, disabled after an intervening operation. No general operation-history UI or dedicated Redo control. |

### Reshape revision history

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| D1 | Rebase branch | Default drag rebases the source **and descendants** onto the target. Rebase onto Selected uses this source mode, with selected destination(s). “Branch” here means that revision subtree, not a bookmark-only operation. [Drag modes][drag-modes], [rebase command][rebase], [CLI flags][history-service]. | **Missing.** |
| D1 | Rebase one revision | R during drag chooses revision mode, moving only the selected revision rather than its descendant subtree. It rewrites history; Duplicate creates an additional change. [Drag modes][drag-modes], [CLI flags][history-service]. | **Missing.** |
| D2 | Duplicate / Duplicate Onto | Context action duplicates the revision with its existing parents; D drag duplicates onto the target. The source remains. [Duplicate][duplicate], [graph dispatch][graph-dispatch], [CLI flags][history-service]. | **Missing.** |
| D3 | Merge revisions | Selected revisions or M drag create a new working-copy revision with the chosen revisions as parents. It does not squash their contents into one of the existing revisions. [Merge command][merge], [graph dispatch][graph-dispatch]. | **Missing.** |
| D4 | Abandon one or several revisions | Context/graph action abandons the chosen revision(s), with multi-selection supported. [Abandon][abandon], [graph selection][graph-app], [CLI call][history-service]. | **Missing:** automatic source abandonment caused by squash is not a separate Abandon UI. |

### Inspect and edit file content

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| A4 / A5 | Single-file and multi-file diffs | Click a changed file for a diff, or open the whole revision's multi-file diff. Open File in Working Copy is also available. [Open handlers][open], [multi-diff][multi-diff], [details UI][details-ui]. | **Missing:** files are informational rows/tooltips, with no diff/open callback. Other T3 Diff tabs do not make this panel feature present. |
| B6 | Edit mutable revision content in diffs | Mutable historical revisions have editable diff content; saving writes edits back to that revision without first invoking Edit to switch `@`. Saves for the same repository/revision are batched. Immutable revision diffs are read-only. [Multi-diff eligibility][multi-diff], [edit file service][edit-fs], [content write][content-service]. | **Missing:** message editing does not edit file content. |
| A6 | Compare with a revision / view historical file | Compare all files or a working-copy file against a chosen revision; historical file viewing is separate. Prompt choices generally suggest ancestors, while a graph-selected revision can be compared with the working copy. [All-files comparison][compare-all], [file comparison][compare-file], [historical file][view-file]. | **Missing:** no comparison picker or historical file viewer. This is not an arbitrary two-historical-revision comparison UI. |
| B7 | Resolve merge conflicts | Conflict resources open VS Code's merge editor; repository file decorations also highlight conflicts. [Resource action][resource-state], [merge invocation][merge-host], [merge inputs][merge-provider]. | **Partial:** conflict indicators and squash restrictions exist; no conflict resolver or merge editor. |

### Bookmarks

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| E1 | Create/move/delete local bookmarks | Set Bookmark selects an existing local name or creates one; local pills can be dragged to another revision; Delete Bookmark removes a local bookmark. Remote pills are displayed but are not local move/delete controls. [Set][bookmark], [delete][bookmark-delete], [drag UI][bookmark-drag], [CLI calls][bookmark-service]. | **Missing:** no bookmark display or management. |
| E2 | Advance bookmarks / Advance & Upload | Advance targets a revision; the combined action advances then uploads. It is different from setting one explicitly chosen bookmark. [Advance][bookmark-advance], [combined action][bookmark-upload], [CLI calls][bookmark-service]. | **Missing.** |

### Repositories and workspaces

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| F2 | Discover/switch repositories | Configurable recursive scanning, active-file-based focus switching, and Show Repository in JJ Log. [Repository manager][repository-manager], [registered focus command][registration]. | **Missing:** the panel follows the existing thread workspace/environment; this is not a repository discovery or switching interface. |
| F1 | Create/open/forget/delete jj workspaces | Add prompts for a name and configured location; workspace pills expose open in current/new window, forget while retaining files, and forget plus directory deletion. [Add][workspace-add], [open][workspace-open], [forget][workspace-forget], [delete][workspace-delete], [menus][manifest]. | **Missing:** resolving the identity of an existing linked workspace is supported, but no workspace management action is exposed. |

### Forge review and publication

| ID | Main feature | Verified JJ View behavior and UI | T3 panel |
| --- | --- | --- | --- |
| E4 | Forge status, links and authentication | GitHub PR, GitLab MR and Gerrit change status/links, mergeability-related indicators and review-comment badges. Auto-detection and OAuth/PAT or provider-specific credentials. [GitHub][github-provider], [GitLab][gitlab-provider], [Gerrit][gerrit-provider], [authentication menu][extension-auth]. | **Missing:** no forge data, badges, links or auth interface in this patch. |
| E4 | Read/reply/resolve review discussions | Inline VS Code comment threads; Reply, Reply & Resolve, Ack, Done, resolve/unresolve, and copy an unresolved-comment summary. Connected provider methods exist for GitHub, GitLab and Gerrit. [Comments UI][comments-provider], [actions][comments], [manager][comments-manager], [GitHub][github-provider], [GitLab][gitlab-provider], [Gerrit][gerrit-provider]. | **Missing.** |
| E3 | Upload changes / upload linear stacks | SCM/graph upload uses a configured jj upload command or a provider/default push. Stack upload can create/retarget linked PRs/MRs on GitHub/GitLab. Linear stacks only; Gerrit uses standard upload instead. [Upload][upload], [stack workflow][upload-stack], [provider sync][github-provider], [GitLab sync][gitlab-provider]. | **Missing by current contract:** the panel must never push. Adding publication would require a deliberate scope decision, which has not been made. |

## Important distinctions for selection explanations

1. **New vs Commit vs Edit vs Describe:** New starts empty work based on chosen parent(s); Commit applies the message to current work and starts the next empty revision; Edit resumes an existing revision; Describe only changes its message. Both New and Commit leave a new empty working-copy revision in common SCM usage, but they differ in whether they explicitly set the old revision's description. Neither “commit” nor “new” means uploading changes. T3 currently implements Describe. [New][new], [commit][commit], [edit][edit], [describe][describe], [CLI calls][describe-commit-service].
2. **Squash Into vs Squash Onto vs Absorb vs Duplicate:** Into rewrites an existing destination; Onto creates a new revision above the destination and transfers the source's changes; Absorb distributes eligible edits among ancestors; Duplicate copies into an additional revision and retains the source. Whole-revision squash, selected-file squash and selected-line squash are separate levels of control. [Squash modes][squash-service], [absorb][absorb-service], [duplicate][history-service], [file squash][squash-files], [selection squash][squash-selection].
3. **Rebase branch vs revision:** Branch mode moves source plus descendants; revision mode moves the selected revision. The UI implements both through drag modifiers, while the context command uses branch/source mode. [Drag modes][drag-modes], [context command][rebase], [CLI flags][history-service].
4. **Squash messages differ between entry points:** JJ View's parent/ancestor command opens a combined-message editor when both revisions have descriptions. The graph drag calls squash directly, without that message-editor workflow; the process uses a no-op external editor. Do not promise identical message-selection UX for both entry points. T3 always confirms the transfer and offers keep-destination or explicit replacement; unsaved message drafts are not included. [Squash command][squash-command], [graph dispatch][graph-dispatch], [process editor setting][no-op-editor], [T3 UI][t3-patch].

## README discrepancies and limits

1. **Advertised command missing:** The README lists “Show Current Change,” but no matching contributed command, registration or handler was found in the VS Code or web source. Graph highlight/scroll infrastructure exists, which does not establish that named command. Exclude it as a selectable implemented feature. [README command list][readme-commands], [manifest commands][manifest], [VS Code registration][registration], [web registration][web-registration], [highlight handling][graph-app].
2. **Dedicated parent/child navigation not verified:** The README claims quick focus switching between parents and children. Selecting graph nodes and invoking Edit are implemented, but no dedicated parent/child navigation command or button was found. Graph keyboard handling covers selection and drag modifiers; node keyboard handling covers Enter/Space. Do not list a separate parent/child navigator. [README SCM claims][readme-scm], [graph UI][graph-app], [node UI][graph-nodes], [registration][registration].
3. **Incorrect Discard Change description:** The README describes discarding all files within a change. The actual registered action is a diff-hunk operation that replaces one selected changed line range with the original content and saves it. Whole-file Restore and revision Abandon are separate implemented features. [README command list][readme-commands], [discard handler][discard], [manifest menus][manifest], [restore][restore], [abandon][abandon].
4. **“Stage modifications” is loose terminology:** There is no separate Git-index-style Stage/Unstage UI among the contributed commands. Files/hunks/selections can be transferred via squash, and Commit starts the next working copy. Describe the concrete workflows rather than promising an index. [README SCM claims][readme-scm], [manifest][manifest], [file squash][squash-files], [selection squash][squash-selection], [commit][commit].
5. **GitLab unresolved badge is an approximation:** The status mapping uses total `user_notes_count` (or 1) when discussions are unresolved, not a count computed from unresolved discussions. The discussion fetch separately loads actual threads. Thus the displayed number is not guaranteed to equal pending unresolved threads/comments. GitHub's status mapping instead counts unresolved review threads. [GitLab mapping][gitlab-count], [GitLab discussions][gitlab-provider], [GitHub mapping][github-count].
6. **No universal comparison picker:** The comparison handlers compare a chosen revision with working-copy content. Graph selection expands possible source revisions, but there is no demonstrated two-arbitrary-historical-revision UI. [All-files comparison][compare-all], [file comparison][compare-file], [menus][manifest].
7. **Do not assume web/VS Code parity:** The README describes VS Code. In standalone web registration, comment commands create a `BaseCommandContext` without a comments manager, so the shared comment handlers return or optional-chain to no service. The four process-monitor commands are explicit no-ops. The web merge callback opens a conflicted diff, not the VS Code three-way editor. These limits do not invalidate the connected VS Code implementations. [Web context and registration][web-registration], [context services][command-context], [comment handlers][comments], [web process stubs][web-process-stubs], [web merge callback][web-merge], [VS Code merge provider][merge-provider].
8. **Publication is conditional:** Forge operations require credentials, a usable remote/provider configuration and a compatible jj/upload setup. Stack synchronization is implemented for GitHub/GitLab, rejects non-linear history and excludes Gerrit stack mode. UI presence does not guarantee every repository can upload successfully. [Upload][upload], [stack validation][upload-stack], [authentication][extension-auth].

The scoped source inspection found connected implementations for the principal revision actions requested above; Squash Onto, Absorb, per-file actions and both rebase drag modes are not merely README promises. Findings about absence are bounded to this snapshot and these inspected UI registrations/handlers.

## Actual T3 contract coverage

The patch implements its intentionally narrow contract: compact rows, `@` plus at most ten ancestors, descriptions/file status, on-demand description editors, retained/stale drafts, whole-working-copy squash with confirmation, latest-panel-action undo, actual thread environment/workspace resolution, permission checks and immutable/conflicted/stale-operation restrictions. Missing jj/non-repository states and persistent/reopenable tabs are also wired. [Contract][t3-contract], [patch][t3-patch].

Useful patch anchors for subsequent review: server reads and limits around lines 641–703; description/squash/undo actions around 775–860; refresh triggers around 1212–1315; row/edit/squash controls around 1420–1626; informational file rows around 1631–1685; confirmation/message policy around 1690–1806; RPC/schema additions around 2069–2385. These are patch-file line numbers, not upstream source line numbers.

Two qualifications prevent overstating this coverage: the service reads `ancestors(@)` with a limit of 11, so merge histories yield ancestor rows rather than a single parent chain; file rows do not open a diff. Operation-checked mutations and scoped undo are explicit product safeguards, not substitutes for the absent history/file-management features. No running-app, forge, patch-application or runtime validation was performed.

## Research boundaries

Only this new document was written. The reference clone, existing docs, T3 patch, contract and other working-copy changes were preserved. No jj mutation, revision description, Git commit, installation, test run, app interaction or publication was performed. Visual explanations and feature selection remain with the parent thread; no feature code change is proposed here.

[manifest]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/package.json
[readme]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/README.md
[readme-commands]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/README.md#L116-L165
[readme-scm]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/README.md#L37-L46
[registration]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/vscode/register-commands.ts
[scm-model]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/scm-model.ts
[resource-state]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/scm-resource-state.ts#L50-L105
[graph-app]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/webview/log/LogApp.svelte
[graph-nodes]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/webview/log/components/CommitNode.svelte
[graph-layout]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/webview/log/graph-compute.ts
[details-ui]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/webview/commit-details/CommitDetails.svelte
[details-controller]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/controllers/commit-details-controller.ts
[describe]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/describe.ts
[change-detection]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/change-detection-manager.ts
[new]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/new.ts
[new-payload]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/vscode/payloads/new.payload.ts
[commit]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/commit.ts
[commit-prompt]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/commit-prompt.ts
[describe-commit-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L1166-L1181
[edit]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/edit.ts
[edit-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L1333-L1335
[new-before]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/new-before.ts
[new-after]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/new-after.ts
[new-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L1057-L1086
[squash-command]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/squash-revision.ts
[graph-dispatch]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/controllers/log-view-controller.ts#L619-L660
[drag-modes]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/webview/log/utils/drag-modifiers.ts
[squash-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L895-L953
[absorb]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/absorb.ts
[absorb-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L1408-L1422
[squash-files]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/squash-files.ts
[squash-selection]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/squash-selection.ts
[partial-squash-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L1365-L1406
[restore]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/restore.ts
[restore-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L638-L655
[discard]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/discard-change.ts
[undo-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L990-L996
[history-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L955-L988
[rebase]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/rebase.ts
[duplicate]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/duplicate.ts
[merge]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/merge.ts
[abandon]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/abandon.ts
[open]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/open.ts
[multi-diff]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/multi-diff.ts
[edit-fs]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-edit-fs-service.ts
[content-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L844-L892
[compare-all]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/compare-all-files-with-revision.ts
[compare-file]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/compare-file-with-revision.ts
[view-file]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/view-file-at-revision.ts
[merge-provider]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/vscode/providers/vscode-merge-provider.ts
[merge-host]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/vscode/vscode-host-environment.ts#L270-L305
[bookmark]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/bookmark.ts
[bookmark-delete]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/bookmark-delete.ts
[bookmark-drag]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/webview/log/components/DraggableBookmark.svelte
[bookmark-advance]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/bookmark-advance.ts
[bookmark-upload]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/bookmark-advance-upload.ts
[bookmark-service]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L446-L481
[repository-manager]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-repository-manager.ts
[workspace-add]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/workspace-add.ts
[workspace-open]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/workspace-open.ts
[workspace-forget]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/workspace-forget.ts
[workspace-delete]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/workspace-delete.ts
[github-provider]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/github-provider.ts
[gitlab-provider]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/gitlab-provider.ts
[gerrit-provider]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/gerrit-provider.ts
[extension-auth]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/vscode/extension.ts#L236-L299
[comments-provider]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/vscode/providers/vscode-comments-provider.ts
[comments]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/comments.ts
[comments-manager]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/comments-manager.ts
[upload]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/upload.ts
[upload-stack]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/commands/upload-stack.ts
[no-op-editor]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/jj-service.ts#L362-L388
[gitlab-count]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/gitlab-provider.ts#L685-L715
[github-count]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/github-provider.ts#L597-L620
[web-registration]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/web/src/commands/register-web-commands.ts
[command-context]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/src/core/host/command-context.ts
[web-process-stubs]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/web/src/commands/register-web-commands.ts#L362-L365
[web-merge]: https://github.com/brychanrobot/jj-view/blob/f7d9abca3cfa57adf2c0ee7b572ba9ea86fc8e51/web/src/App.svelte#L1020-L1036
[t3-patch]: ../packages/t3code-web/patches/jj-panel.patch
[t3-contract]: ../packages/t3code-web/patches/jj-panel.md
