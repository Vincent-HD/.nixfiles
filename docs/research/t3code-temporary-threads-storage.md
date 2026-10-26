# T3 Code temporary threads: storage and deletion findings

> Checked 26 October 2026 against the Nix-resolved source for t3code-web version
> 0.1.2-nightly.20261022.3541, pinned upstream commit
> 044f07257c9684ae4543bd1e1ebf9c394e9e3830. Scope: backend persistence, deletion,
> provider state, crash recovery, and multiple clients.

## Source/version verification

I resolved nix eval .#t3code-web.src --raw to
/nix/store/vmgf2d8kf3bhawy85dwp5nb7zrmfhyi9-source and used that source tree. The Nix package
pins the named tag and a fixed archive hash, and the local patch-base record names the reviewed
commit:
[package pin](../../packages/t3code-web/default.nix#L14-L20),
[patch-base record](../../packages/t3code-web/patches/README.md#L13-L16).
I did not use /tmp/t3-rebase as source evidence; it is at local HEAD 867200d6 and has an
uncommitted ChatView.tsx change, which I left untouched.

## Recommendation

For a small local feature, treat “temporary” as a thread that exists normally while open and is
removed from T3’s usable history after the user confirms leaving. Reuse the existing
thread.delete lifecycle command. If the UI needs to know which threads get this behavior, add a
server-owned temporary marker to the thread contract/event payload.

This is a convenience and history-visibility feature, not a private or zero-retention mode:
thread.delete tombstones the thread and schedules resource cleanup; it does not erase all T3
event history, provider-owned conversation data, workspace changes, or copies on disconnected
clients. The UI should describe that boundary accurately.

If “temporary” means that prompts and responses must never be persisted, this approach does not
meet the requirement. That would need a separate non-durable orchestration path and provider-specific
retention controls. It is substantially larger and still cannot erase data already retained by a
remote provider.

## What the existing delete command does

The existing thread.delete command already cancels active runs, emits a thread.deleted event
whose payload sets deletedAt, and schedules cleanup effects for provider sessions, scheduled
tasks, terminals, previews, and attachment files. This is the server behavior to reuse:
[ThreadDeletion.ts:56-67, 69-127, 185-238](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ThreadDeletion.ts#L56-L67).

Deletion is a tombstone, not a row purge:

- The projection handler upserts the thread into orchestration_v2_projection_threads, setting
  deleted_at and retaining its JSON payload. It does not delete the thread row or its associated
  timeline rows:
  [ProjectionStore.ts:1934-2002](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ProjectionStore.ts#L1934-L2002).
- Shell/history reads exclude a thread when deletedAt is set, and clients switch their local
  thread state to deleted and remove its cache after receiving the event:
  [ProjectionStore.ts:7230-7247](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ProjectionStore.ts#L7230-L7247),
  [threads.ts:401-421, 472-483](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/packages/client-runtime/src/state/threads.ts#L401-L421).
- The canonical event table stores event payloads as JSON. User and assistant messages, reasoning,
  and plans are turn-item payloads with text fields:
  [001_OrchestrationEvents.ts:7-22](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/persistence/Migrations/001_OrchestrationEvents.ts#L7-L22),
  [orchestrationV2.ts:1339-1380](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/packages/contracts/src/orchestrationV2.ts#L1339-L1380),
  [OrchestrationEventStore.ts:445-519](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/persistence/OrchestrationEventStore.ts#L445-L519).
- Event compaction removes some superseded state events, but deliberately keeps thread.created,
  thread.deleted, and every turn-item.updated event; it also retains the first and latest
  message/node events. Compaction therefore is not thread-history erasure:
  [ProjectionMaintenance.ts:199-242, 303-350](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ProjectionMaintenance.ts#L199-L242).
- The cleanup effects do remove some separate resources: terminal close requests delete terminal
  history; scheduled tasks are deleted; previews are closed; attachment files are unlinked.
  Removing an attachment file is not secure overwrite, and event payloads can still retain its
  metadata:
  [ResourceCleanupService.ts:49-95](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ResourceCleanupService.ts#L49-L95).
- The deletion plan does not revert workspace edits or remove checkpoint refs. T3 checkpoints are
  hidden Git refs, separate from the conversation record:
  [overview.md:82-85](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/docs/internals/overview.md#L82-L85).

## Provider sessions and artifacts

Deletion records a provider-session detach and asks the manager to revoke the thread’s MCP
credential. The manager removes the thread attachment and, when supported, unloads the native
provider thread; some session types are then released. The provider adapter contract exposes
unloadThread, but no general operation to erase a provider conversation:
[ProviderSessionManager.ts:2398-2505](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ProviderSessionManager.ts#L2398-L2505),
[ProviderAdapter.ts:550-632](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/packages/provider-core/src/server/ProviderAdapter.ts#L550-L632).

The contract also states that the provider owns its conversation. Therefore, T3 deletion cannot
promise removal of provider CLI transcripts, native session databases, or remote-provider copies.
Provider-specific erase APIs would need separate investigation and integration; otherwise treat
those artifacts as retained:
[orchestrationV2.ts:443-450](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/packages/contracts/src/orchestrationV2.ts#L443-L450).

## Crash recovery and multiple clients

The event sink writes events, projections, and cleanup effects in a database transaction, then
publishes after commit. The effect outbox is durable. Startup recovery requeues replay-safe cleanup
effects such as provider detach, terminal/preview/task cleanup, and attachment cleanup. The worker
defaults to five attempts before recording a failed effect:
[EventSink.ts:265-285, 396-465](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/EventSink.ts#L265-L285),
[EffectOutbox.ts:123-142, 496-525](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/EffectOutbox.ts#L123-L142),
[EffectWorker.ts:591-593, 759-783](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/EffectWorker.ts#L591-L593),
[serverRuntimeStartup.ts:542-554](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/serverRuntimeStartup.ts#L542-L554).
So a server crash after the deletion command commits can recover cleanup; a permanent cleanup failure
is still possible and should not be described as guaranteed physical erasure.

A client crash or network loss before the confirmed-delete command reaches the server leaves the
temporary thread undeleted. If cleanup must also cover that case, add a server-owned expiry/sweeper.
An expiry column and index are a clean query path; an open thread on another device must renew its
lease or the sweeper could delete a thread still in use.

The server is the shared environment for web, desktop, and mobile clients. Deleting a thread is
global: subscribers receive the delete event, and their client-runtime cache is removed. Web stores
thread snapshots in IndexedDB and mobile in its local database, so a disconnected client cannot be
immediately scrubbed by the server and may retain its cached copy until it syncs:
[overview.md](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/docs/internals/overview.md#L1-L16),
[storage.ts:114-124, 830-843, 905-910](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/web/src/connection/storage.ts#L114-L124),
[environment-cache-store.ts:147-168](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/mobile/src/connection/environment-cache-store.ts#L147-L168).
Avoid treating socket disconnect or page teardown as confirmation of departure: it is ambiguous in
the presence of reconnects and other clients. Use an explicit confirmed action; use a server-side
expiry only if abandoned temporary threads also need eventual cleanup.

## Smallest implementation and rough complexity

1. **History-cleanup behavior (low, roughly 1–3 engineering days plus UI work).** Add a server-owned
   temporary flag to the thread create/update contract and persisted thread payload. The current
   thread contract has deletedAt but no temporary flag:
   [orchestrationV2.ts:373-440](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/packages/contracts/src/orchestrationV2.ts#L373-L440).
   For create-only behavior, add a default-false field to thread.create; to mark existing threads,
   extend thread.metadata.update or add a small dedicated setter. On confirmed leave, call the
   existing delete lifecycle path; no new deletion command or SQL-column migration is needed for a
   defaulted field stored in the existing JSON projection. The existing command path is
   ThreadLifecycleService.delete / thread.delete and client helper deleteThread:
   [ThreadLifecycleService.ts:90-108](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/apps/server/src/orchestration-v2/ThreadLifecycleService.ts#L90-L108),
   [commands.ts:409-428](https://github.com/pingdotgg/t3code/blob/044f07257c9684ae4543bd1e1ebf9c394e9e3830/packages/client-runtime/src/operations/commands.ts#L409-L428).
   Likely change points are packages/contracts/src/orchestrationV2.ts for the thread/create/update
   schemas, packages/client-runtime/src/operations/commands.ts for the command helper,
   apps/server/src/orchestration-v2/Orchestrator.ts for command handling,
   apps/server/src/orchestration-v2/ProjectionStore.ts for the projected field, and the
   client-runtime command/state path for marking and deleting. Keep thread.delete as-is.
   If the confirmed leave must survive client failure, add an indexed expiry field, server sweep,
   a SQLite migration, and active-client lease handling (medium, roughly 3–7 days). Web cache
   eviction happens when the client receives thread.deleted, so connected clients need no new
   delete protocol.
2. **Truly nonpersistent thread (high, multiple weeks and provider-specific).** Avoid writing
   conversation events/projections/receipts to the durable event store, avoid persistent client
   snapshots, and define what happens to in-flight work after a server restart. Then investigate
   deletion/ephemeral controls for every provider driver. This still cannot guarantee removal of
   already-synced provider data or workspace effects.

For a first pass, test the committed-delete/restart path, cleanup effect retry/failure, active-run
cancellation, and deletion from one client while another is connected or offline. Existing focused
server/client areas include ThreadDeletion.test.ts, ProviderRuntimeRecoveryService.test.ts,
EffectWorker.test.ts, and threads-sync.test.ts. No tests, builds, app restart, browser, or live
database access were performed for this investigation.
