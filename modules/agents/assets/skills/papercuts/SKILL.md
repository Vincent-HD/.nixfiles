---
name: papercuts
description: Record small, concrete workflow friction with the Papercuts CLI. Use proactively during agent work when a dead-end tool call, stale cache, broken link, misleading error, flaky command, undocumented setup step, or non-obvious gotcha interrupts the primary task.
---

# Papercuts

Record each distinct friction point at most once per task. Keep the observation to one or two sentences: state what you were doing, what got in the way, and optionally a suspected cause or fix.

- Treat a papercut as workflow friction, not an accomplishment log or issue tracker. Keep using the project's normal workflow for bugs.
- Never include secrets, raw transcripts, or large command output.
- Pipe the observation to `papercuts add --stdin --source codex` when running in Codex, or use `--source generic` in Cursor and other agents.
- Continue the primary task if capture fails. Never record a Papercuts capture failure as another papercut.
- Never review transcripts automatically.
