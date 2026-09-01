# CodeBurn/Cursor usage investigation

> **Date:** 1 September 2026  
> **CodeBurn checked:** `v0.9.23` (the version packaged by this flake)  
> **Scope:** upstream source and provider documentation, plus a read-only local smoke test

## Conclusion

CodeBurn does not read Cursor's billing/admin endpoint by default. It reads the
Cursor IDE's local SQLite database and estimates cost from whatever usage data
that database exposes. This is the expected upstream behavior, not something
that can be fixed by an MCP port, Cursor hook, or additional credentials.

The current flake already satisfies the required setup: the package uses Node
24 (which provides the built-in `node:sqlite` driver), and the normal Linux
Cursor data directory is the path CodeBurn probes. No CodeBurn-specific Cursor
environment variable is documented or needed.

## How the upstream provider works

The provider probes one database per platform:

| Platform | Database |
| --- | --- |
| Linux | `~/.config/Cursor/User/globalStorage/state.vscdb` |
| macOS | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` |
| Windows | `%APPDATA%/Cursor/User/globalStorage/state.vscdb` |

These paths and the SQLite storage format are documented in CodeBurn's [Cursor
provider documentation](https://github.com/getagentseal/codeburn/blob/v0.9.23/docs/providers/cursor.md)
and implemented in [`src/providers/cursor.ts`](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/providers/cursor.ts#L80-L105).

The parser reads two key families from `cursorDiskKV`:

1. `bubbleId:*` rows, which contain message-level fields such as
   `tokenCount`, model, timestamp, text, and code blocks.
2. `agentKv:blob:*` rows, which contain streamed prompt/context/reply content
   and request metadata.

It also reads `composerData:*` rows for the latest context-meter snapshot and
walks `User/workspaceStorage/*` to attribute composers to projects. See the
[provider implementation](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/providers/cursor.ts#L297-L322)
and its [workspace mapping logic](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/providers/cursor.ts#L89-L227).

For current Cursor builds, upstream explicitly notes that per-bubble
`tokenCount` is often `{0,0}`. In that case CodeBurn prefers the latest
`composerData.promptTokenBreakdown.totalUsedTokens` or `contextTokensUsed`,
then stream/text length estimates. That context meter is a snapshot, not a
cumulative per-turn counter, so local results can undercount. The source says
that matching the Cursor admin console requires the opt-in Cursor Admin API
`POST api.cursor.com/teams/filtered-usage-events`; the local SQLite parser does
not call that API. See the [crediting source comments and implementation](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/providers/cursor.ts#L458-L489)
and [input-source selection](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/providers/cursor.ts#L618-L711).

The provider is bounded to a six-month lookback, even when the user selects
`all`, and large databases have a 250,000-bubble scan budget. Both limits are
documented in the [upstream provider notes](https://github.com/getagentseal/codeburn/blob/v0.9.23/docs/providers/cursor.md#quirks).

## Runtime and setup requirements

CodeBurn `v0.9.23` replaced the earlier `better-sqlite3` binding with Node's
built-in `node:sqlite`; upstream says it is stable in Node 24 and experimental
in Node 22/23. The [SQLite wrapper](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/sqlite.ts#L7-L10)
loads that module lazily and opens Cursor databases read-only. The package
metadata requires Node `>=22.13.0` ([`package.json`](https://github.com/getagentseal/codeburn/blob/v0.9.23/package.json#L47-L49)),
while URI-based immutable fallback support starts at Node 22.15 according to
the [same wrapper](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/sqlite.ts#L140-L159).

CodeBurn's README describes `better-sqlite3` as an optional dependency for
Cursor/OpenCode, but that statement is stale relative to the `v0.9.23`
source, which uses `node:sqlite`. The Nix package's Node 24 runtime therefore
does not need a separately packaged native SQLite addon.

There is no Cursor-specific `CODEBURN_*` path override in the current provider.
The upstream README's environment-variable table lists overrides for other
providers but not Cursor; the Cursor source has only an internal test
constructor argument (`createCursorProvider(dbPathOverride?)`). If Cursor is
launched with a non-default `--user-data-dir`, the database moves with that
profile and the current provider will not discover it automatically. That
would require either launching CodeBurn with a future upstream override or
changing the provider/package.

Because Cursor writes the database using SQLite WAL, CodeBurn may need to read
the `state.vscdb-wal` sidecar too. The upstream wrapper fingerprints and copies
the main DB plus optional `-wal` into a private cache when a read-only open
cannot create sidecars; it does not modify Cursor's database. See the
[read-only fallback implementation](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/sqlite.ts#L181-L216)
and [open logic](https://github.com/getagentseal/codeburn/blob/v0.9.23/src/sqlite.ts#L338-L418).

## Local verification on `pc-fixe`

Read-only checks on 1 September 2026 found:

- `~/.config/Cursor/User/globalStorage/state.vscdb` exists and is readable;
- the database is actively accompanied by a `state.vscdb-wal` sidecar;
- `codeburn --version` returns `0.9.23`;
- `codeburn doctor --provider cursor --json` reports `status: ok`, one existing
  candidate, one sampled session, and `parseFailed: 0`;
- `codeburn report --provider cursor -p today --format json` reports nine
  calls, but zero input tokens and 546 output tokens for today's current
  session; this is consistent with the upstream documented limitation when
  Cursor's local per-bubble input counts are zero.

The current result therefore indicates that discovery and SQLite access are
working. If the expected number is Cursor's web admin/usage-console total, the
gap is an upstream data-source limitation: an Admin API integration (with the
appropriate Cursor account/team authentication and consent) would be needed
for parity. If the concern is missing older local sessions, check the six-month
lookback and the large-database scan warning first.

## Recommended next checks

Run these without changing configuration:

```sh
codeburn doctor --provider cursor --json
codeburn audit --provider cursor
codeburn report --provider cursor -p today --format json
codeburn report --provider cursor -p all --format json
```

If `doctor` is `OK` and the report contains calls, do not add a port or MCP
configuration for usage collection. Compare like-for-like periods with the
Cursor UI, and treat CodeBurn's Cursor costs as estimates. If CodeBurn reports
zero despite a readable DB, first clear its versioned cache (or run with a
fresh `$CODEBURN_CACHE_DIR`) and rerun while Cursor is idle; upstream warns
that a live SQLite database can race reads and that cache poisoning can follow
Cursor schema changes ([cache behavior](https://github.com/getagentseal/codeburn/blob/v0.9.23/docs/providers/cursor.md#caching),
[bug-fixing guidance](https://github.com/getagentseal/codeburn/blob/v0.9.23/docs/providers/cursor.md#when-fixing-a-bug-here)).
