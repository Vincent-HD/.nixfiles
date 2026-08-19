## Agent workflow preferences

- Prefer Jujutsu (`jj`) for local revision management when the checkout is jj-enabled. Use Git when the repository, import-tree, or a host integration requires it; do not initialize or convert a checkout just to satisfy this preference.
- Prefer Nix-managed configuration and packages over ad hoc local setup; use temporary Nix-backed tools for one-off diagnostics.
- Keep communication concise and changes focused; avoid speculative abstractions.
- Use iterative improvement passes when they directly improve tooling or startup performance.

### Jujutsu revisions

Keep history as **one logical change per revision**, with conventional, why-focused descriptions. Do not mash unrelated topics into `@`.

Use the shared Agent Skills (installed under `~/.agents/skills`):

| When | Skill | Intent |
| ---- | ----- | ------ |
| While implementing; “jj” / absorb / describe | `jj-auto-revise` | Describe `@` at start of a concern; print a progress block at prompt boundaries; do not commit when a piece ends; on each new prompt, continue if related, else `jj commit` then describe the new concern; absorb/squash-into for ancestor follow-ups |
| Later cleanup; stacked PRs; squash & resplit a wip stack | `jj-resplit-stack` | Backup (bookmark + range duplicate) → squash blob onto BASE → peel feature/FE-BE slices with a running progress block → related tests per rev |
| Unresolved jj conflicts after rebase/merge; “fix conflicts” | `jj-solve-conflict` | Backup (bookmark + duplicate), teleport with `jj new` onto the oldest conflict, resolve, squash with `--use-destination-message`, keep a running remaining-count |

**Never push** (`git push` / `jj git push` / remote bookmark push) while following those skills. Local bookmarks only unless the user explicitly asks to publish.

Agent shells are PTYs. Bare `jj status` / `jj log` / `jj diff` / `jj op *` / `jj help` / `jj bookmark list` open `less` and hang forever (often with empty captured output). Prefix every standalone `jj` and `git log`/`git diff` with `PAGER=cat GIT_PAGER=cat`. The skill helper scripts already do this. Never run `jj op show -p` unpiped.

## Nix environment

This machine is managed by Nix. When a command-line tool is not available,
run it temporarily with `comma` (for example, `, jq`) or use
`nix run nixpkgs#jq -- <arguments>`. Do not install a tool globally just
to complete a task.

## Shared MCP catalog (Executor)

MCP tools on this machine live in **Executor**, not in each editor. Cursor, Codex, and VS Code already connect to that one catalog.

When you need a tool, or you are about to add or create an MCP server, ask Executor first:

- Call Executor `skills` with name `execute`, then `tools.search({ query: "..." })` to see what is already shared.
- The catalog currently includes GitHub, Context7, NixOS package and option docs (`nixos`), browser automation, Postgres, and Arch ops.
- Do not add a client-local MCP in Cursor, Codex, or VS Code for something Executor already exposes.
- If the tool is missing, ask to add it to the Executor catalog so every client gets it, instead of wiring a one-off server into a single agent.

## Response sections and feedback

When proposing work, requesting feedback, or showcasing changes:

- Use indexed items so the user can answer precisely: `1`, `2`, `3` for one
  section; `A1`, `A2`, `B1` when there are multiple sections.
- Put completed or proposed changes under a clearly labeled `SHOWCASE`
  section when presenting them for review.
- Add a clearly labeled `FEEDBACK NEEDED` section only when a real user
  question or decision is needed. Put every question there, indexed, and keep
  it separate from `SHOWCASE`; omit the section when there are no questions.

## Open-ended follow-ups

When the user ends a task with an open-ended prompt such as "next steps?",
"anything else?", "something else?", "anything remaining?", or "what's next?":

- Treat it as a genuine invitation to suggest additional improvements, refactors, tests, docs, or edge cases.
- Batch all suggestions in one message instead of offering them one at a time.

When the user asks "any other questions?" or "need anything from me?", collect
all pending unknowns in one batched message. If there are none, say:
"Nothing else — all good."

## Node project defaults

When working in a Node project without more specific repository instructions, use these baseline requirements:

- TypeScript 7.0 or newer.
- pnpm 11 or newer.
- Vite 8.1 or newer.
- Oxlint and Oxfmt.

## JavaScript and TypeScript guidance

These conventions apply when working on JavaScript or TypeScript assets; repository-specific language and toolchain rules remain authoritative.

- Prefer arrow functions over function declarations.
- Use kebab-case for files and descriptive names; avoid shorthands.
- Do not type cast (`as`) unless absolutely necessary.
- Remove unused code and avoid repetition.
- Use `Boolean` over `!!`.
- Avoid multiple arguments; prefer a single object.
- Avoid exporting things not intended for external use.
- Validate using a standard schema library, such as Effect Schema or Zod, rather than manual checks.
- Prefer early returns over `else` when they make control flow clearer.

## Effect guidance

When working with Effect code:

- If available, read the Effect reference repository under `~/.references/effect` for API examples.
- Prefer Effect and `@effect/platform` APIs; use `Effect.promise` as a fallback.
- Use `Effect.fn` and `Effect.withSpan` for effectful functions.
- Use qualified errors with `Schema.TaggedError`.
- Avoid unnecessary destructuring; prefer dot notation.

## Testing guidance

- Avoid mocks; test actual implementation.
- Debug by running a single file, not the whole suite.
- Use full paths and `--run` for fast feedback when the test runner supports them.
- Add `.only` to isolate a single failing test, then remove it before handoff.
- Run the affected project's own focused tests, lint, typecheck, and formatting commands when they exist.

Run these checks once before the final summary when a pnpm project is in scope, not after every change:

```bash
pnpm test
pnpm lint
pnpm typecheck
pnpm fmt
```

## Comment guidance

- Default to no comments; add one only when the why is non-obvious.
- Avoid comments that repeat what code does, commented-out code, obvious comments, or comments used instead of better naming.

<!-- papercuts:begin v1 -->
## Papercuts

- Proactively record small, concrete friction encountered while working.
- Use one or two sentences: state what was being done, what got in the way, and optionally a suspected cause or fix.
- Record each distinct issue at most once per task.
- Never include secrets, raw transcripts, or large command output.
- Keep using the project's normal issue workflow for bugs; Papercuts is a friction journal.
- Pipe the observation to `papercuts add --stdin --source codex`.
- Continue the primary task if capture fails, and never record that failure as another papercut.
- Never review transcripts automatically.
<!-- papercuts:end -->

<!-- antislop:begin v1 -->
## Antislop

- When you fix or refactor a clear anti-pattern, file a rule so later sessions avoid it.
- Keep the rule to one sentence: what to avoid, and what to do instead.
- Use the repository `.antislop.jsonl` for repo-specific patterns. Use `--global` for language or tooling rules (`~/.antislop.jsonl`).
- Record with `antislop add "Avoid X, prefer Y instead" --tag <area>`. Add `--pattern` and `--pattern-lang` when a linter can catch it.
- Continue the primary task if filing fails, and never record that failure as another rule.
- Check open rules at the start of a session with `antislop list --format md`.
<!-- antislop:end -->
