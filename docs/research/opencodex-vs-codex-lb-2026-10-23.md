# OpenCodex Cursor fixes and codex-lb as an alternative

Checked 2026-10-23 against upstream GitHub release metadata, documentation, and source. No services or account credentials were changed during this comparison. Scope: whether Soju06/codex-lb can replace OpenCodex for ChatGPT pooling and Cursor subscription routing.

Later the same day, OpenCodex was removed from this configuration after its usage history and account credentials were exported outside the repository. This document remains the comparison that led to that decision.

## OpenCodex: installed version and shipped Cursor fixes

The repository pins OpenCodex **2.91.0**. The active Linux
`opencodex-proxy.service` also starts `/nix/store/...-opencodex-2.91.0/bin/ocx`.
This matches the latest stable GitHub release (2026-10-22) and npm `latest`;
there is no newer stable version to upgrade to at inspection time.
[Release](https://github.com/lidge-jun/opencodex/releases/tag/v2.91.0),
[npm metadata](https://registry.npmjs.org/@bitkyc08/opencodex).

Several concrete Cursor fixes have shipped and are already included locally:

- **2.52.0, September 12:** extended the bounded finalize grace to capture a
  checkpoint after a client-tool suspension, addressing a cause of full replay
  and zero cache reuse. This was a partial fix, not a promise that every Cursor
  model now resumes cached state. [Release](https://github.com/lidge-jun/opencodex/releases/tag/v2.52.0),
  [fix #4281](https://github.com/lidge-jun/opencodex/pull/4281).
- **2.80.0, October 7:** preserved bare tool names for Claude Code and changed
  redirects for Claude-family models to factual tool descriptions.
  [Release](https://github.com/lidge-jun/opencodex/releases/tag/v2.80.0),
  [#6640](https://github.com/lidge-jun/opencodex/pull/6640),
  [#6664](https://github.com/lidge-jun/opencodex/pull/6664).
- **2.86.0, October 14:** fixed the Cursor exec gate rejecting a freeform
  code-mode argument shape that downstream Responses repair already supported.
  Its PR reports regression tests, but explicitly says the author did not have
  a live Cursor account for capture. [Release](https://github.com/lidge-jun/opencodex/releases/tag/v2.86.0),
  [#7069](https://github.com/lidge-jun/opencodex/pull/7069).
- **2.91.0:** adds Codex 0.164 request-control compatibility; this is general
  client compatibility, not another declared Cursor-specific repair.
  [Release](https://github.com/lidge-jun/opencodex/releases/tag/v2.91.0).

## OpenCodex: remaining limitations and misleading closure states

Cursor is still documented as experimental. The current guide says native
foreground shell execution remains unavailable on Linux, macOS and Windows
even with native execution opted in; clients should use their own shell tool.
The local config has `providers.cursor.nativeLocalExec = "on"`, but that setting
does not remove the documented foreground-shell restriction.
[Provider guide](https://opencodex.me/guides/providers/).

The checkpoint issue's maintainer comments explicitly distinguished the external
model repair from the unresolved native `auto`/`composer-*` case. The shipped
2.91.0 source still requires `isCursorExternalWireModel(activeRequest.modelId)`
before accepting a checkpoint captured during a client-tool suspension. This
supports a remaining checkpoint-reuse limitation for native models; it does not
prove every native-model request is uncached.
[Issue #4245](https://github.com/lidge-jun/opencodex/issues/4245),
[versioned source](https://github.com/lidge-jun/opencodex/blob/v2.91.0/src/adapters/cursor.ts#L232-L240).

A new report filed October 23 describes Claude Code 2.1.304 through
`/v1/messages` to Cursor Opus failing to deliver client tools on both OpenCodex
2.90.0 and 2.91.0. It was reported on Windows, not reproduced on this Linux host.
Its closed state is **not evidence of a fix**: the bot closed it because it did
not use an accepted issue template. The reporter's proposed root cause remains
unverified, although the versioned bare-tool list does contain the older names.
[Issue and closure comment #7609](https://github.com/lidge-jun/opencodex/issues/7609),
[versioned tool names](https://github.com/lidge-jun/opencodex/blob/v2.91.0/src/adapters/cursor/tool-naming.ts#L181-L201).

The older Grok no-progress-loop report was closed as stale with a request for a
current reproduction, rather than a linked repair proving the reported loop
was eliminated. Closed issue counts alone therefore overstate certainty here.
[Issue #3506](https://github.com/lidge-jun/opencodex/issues/3506).

## Release and maintenance status

- Latest stable: **v1.24.0**, published **2026-08-26**. Its release contains substantial Codex transport, compaction, tool replay, account affinity, cancellation, and accounting fixes. [Release](https://github.com/Soju06/codex-lb/releases/tag/v1.24.0), [latest-stable API](https://api.github.com/repos/Soju06/codex-lb/releases/latest).
- Latest published prerelease: **v1.25.0-beta.9**, published **2026-09-14**. Among its changes: quota-reset recovery, sticky-owner handling, OIDC dashboard sign-in, and removal of subscription-exhaustion fallback to model sources. It is explicitly a prerelease. [Release](https://github.com/Soju06/codex-lb/releases/tag/v1.25.0-beta.9), [release API](https://api.github.com/repos/Soju06/codex-lb/releases?per_page=8).
- Development remains active: main's latest commit at inspection was **72630bb**, dated **2026-10-16**. This is newer than both published releases; current main/hosted docs can describe unreleased behavior. [Commit](https://github.com/Soju06/codex-lb/commit/72630bbfeee9e3b0d9acfb95e2b1e706b8b0188e).

## What it replaces

codex-lb's core product is a **ChatGPT account pool** with usage tracking and API-key controls. It fits sharing the quota of multiple ChatGPT subscriptions through one endpoint. [README](https://github.com/Soju06/codex-lb#readme).

**Cursor as a client is supported; Cursor subscriptions as an upstream account source are a different capability.** Upstream merged Cursor compatibility PR #833 on 2026-06-02: Cursor sends OpenAI-compatible Chat Completions requests, codex-lb adapts model suffixes/payloads and context-limit reporting for the ChatGPT/Codex backend. This landed in v1.20.0. It does not authenticate a Cursor account or spend Cursor subscription quota. [PR #833](https://github.com/Soju06/codex-lb/pull/833), [v1.20.0 changelog](https://github.com/Soju06/codex-lb/blob/v1.24.0/CHANGELOG.md#1200-2026-06-16).

Source inspection found no native Cursor login/account adapter. OAuth/account schemas are ChatGPT-oriented. External model sources accept an OpenAI-compatible base URL, API key and declared capabilities; that can route to a separately supplied compatible gateway, but does not itself implement Cursor subscription authentication. This is a source-based assessment, not a tested assertion that no extension is possible. [Account schema](https://github.com/Soju06/codex-lb/blob/72630bbfeee9e3b0d9acfb95e2b1e706b8b0188e/app/modules/accounts/schemas.py), [OAuth client](https://github.com/Soju06/codex-lb/blob/72630bbfeee9e3b0d9acfb95e2b1e706b8b0188e/app/core/clients/oauth.py), [model-source schema](https://github.com/Soju06/codex-lb/blob/72630bbfeee9e3b0d9acfb95e2b1e706b8b0188e/app/modules/model_sources/schemas.py).

## Codex compatibility and practical caveats

The stable setup documents `/backend-api/codex` for Codex CLI/IDE, `wire_api = "responses"`, lowercase provider `name = "openai"` for remote compaction, `supports_websockets = true`, and `requires_openai_auth = true` for the Codex app. Model availability comes from the upstream catalog and depends on the pool's actual account access; query live `/models` rather than copying a static model list. [Stable client setup](https://github.com/Soju06/codex-lb/blob/v1.24.0/docs/client-setup.md).

Images generation and editing use the Responses image-generation pipeline, with both `/v1/images/*` and Codex-base aliases. The compatibility contract limits requested `n` to 1 and does not support variations. Current main docs also document standalone web search and transport controls; compare the chosen release before copying those newer settings. [Stable Images specification](https://github.com/Soju06/codex-lb/blob/v1.24.0/openspec/specs/images-api-compat/spec.md), [current client docs](https://soju06.github.io/codex-lb/client-setup/).

Pooling does not make every in-progress conversation portable: stored response/conversation state and uploaded files can bind a turn to its owning account. If that owner becomes unavailable, a continuation can fail while other pool accounts remain healthy. [Routing explanation](https://soju06.github.io/codex-lb/routing/).

Changing Codex `model_provider` can hide older sessions from `codex resume` because it filters by provider. Upstream supplies a retag command with dry-run and backup guidance; this changes session metadata and should be a separate migration step after verification. The example `--from openai` must be replaced by the actual previous provider identifier when applicable. [Session migration](https://soju06.github.io/codex-lb/client-setup/#migrating-from-direct-openai-session-retagging).

## Recommendation for this setup

Use native T3 Codex, Cursor and Claude providers for everyday work. This avoids
the cross-provider Responses/tool translation path by construction; it is an
architectural recommendation, not a benchmark claim. Keep OpenCodex optional
only if using Cursor/other providers' models inside the Codex CLI or desktop
client remains valuable. The release fixes justify retrying a known failing
workflow on 2.91.0, but do not justify treating the bridge as fully repaired.

Keep T3's Perso and Evvi instances on their direct ChatGPT accounts if explicit account choice is the goal. A shared codex-lb pool would change that behavior: either instance could use whichever pool account is selected unless separately constrained. This is an architectural inference from the pool design, not a T3 compatibility test.

Consider codex-lb as a separate, pinned **ChatGPT-only pooling trial** if pooling is wanted. Validate a fresh thread, model listing, streaming, tools, images, compaction and resume before changing the default. The upstream flake supports x86_64-linux, aarch64-linux and aarch64-darwin. [Flake](https://github.com/Soju06/codex-lb/blob/v1.24.0/flake.nix).

Do **not** treat codex-lb as a complete replacement for OpenCodex's Cursor-subscription routing. If that cross-provider capability remains a requirement, replacing OpenCodex with codex-lb alone would remove it. Keeping native T3 Cursor alongside native Codex accounts is an alternative architecture; it does not reproduce routing Cursor models through a Codex client. No authenticated runtime comparison was performed, so release history cannot establish which proxy is more reliable for this user's traffic.
