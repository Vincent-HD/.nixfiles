# Usage statistics feature contract

## Purpose and placement

Help the user understand account limits, context pressure, tokens consumed and response
throughput without leaving the chat. Put compact chips immediately below the chat composer.
Put a turn-usage chip beside the completed assistant response's actions/timestamp.

## Required behavior

- Open details on **click**, not hover; keyboard activation and Escape dismissal work.
- Footer details cover reported account quotas/reset information, context used/capacity,
  available completed main-agent session totals, tool/turn time and last-response usage.
- If an authenticated account has no quota windows, label its quota as unavailable and
  keep the provider explanation visible; do not imply the account itself is unavailable.
- A completed response's chip shows its own recorded provider/model, input/output,
  cached input, cache hit, estimated cost, duration and average output tokens/second.
  Changing the current model must not reprice an earlier recorded turn with that model.
- Compact summaries use K/M/B/T, such as `134K` and `1.3B`; details retain exact counts.
- Throughput is output tokens divided by the entire completed turn duration, including
  tools and waits. Do not present this as model generation speed. Available timing
  survives missing token reports. Partial usage is identified and has no definitive TPS.
- Use current `models.dev/api.json` rates, shared across consumers and cached for one hour.
  Account for cached reads/writes and reasoning subsets once. Explain missing pricing
  assumptions, incomplete coverage and canonical-model fallback. Estimates are API-equivalent
  USD costs, not subscription charges; provider-reported cost remains separate. Show costs to
  one decimal without an approximation marker, while retaining the estimate label and explanation.
- Missing data/rates stay unavailable, never invented zeroes. TTFT and the
  system-prompt/tool/message context split are unavailable unless upstream supplies them.

Historical metadata retrieval/backfill is intentionally outside scope: the user requested
future turns. Do not add unbounded transcript downloads to recover old statistics.
Current data comes from provider-turn reports. The patch also forwards Cursor SDK run
usage to new provider turns: input includes cache reads/writes, output already includes
reasoning, and absent counts remain unavailable. Interrupted/failed runs and runs with
observed missing turn reports are partial. Subagent presence is recorded without adding
child usage to the main-agent totals. This does not supply a context-fullness estimate
or account quotas. The patch rebuilds the server as well as the web/desktop renderer;
it does not add mobile UI.

## Integration and verification

In upstream source, inspect `ChatView.tsx`, `chat/ChatComposer.tsx`,
`chat/ComposerUsageFooter.tsx` and `chat/TimelineAssistantRows.tsx` under
`apps/web/src/components/`. The completed-response chip is rendered with the
assistant meta row, which no longer lives in `MessagesTimeline.tsx`.
Turn association is in `turn-usage.logic.ts`; counts/timing in `composer-usage.logic.ts`;
pricing in `models-dev-pricing.ts`, `usage-pricing.ts` and `use-models-dev-pricing.ts`.
Cursor mapping is in `packages/provider-cursor/src/server/turn-usage.ts` and `adapter.ts`.
Prefer upstream recorded run selection and provider-driver IDs over current UI selection.

Existing focused tests under `apps/web/src/components/chat/`:
`composer-usage.logic.test.ts`, `models-dev-pricing.test.ts`, `turn-usage.logic.test.ts`,
`usage-popover.test.tsx`, and the affected `MessagesTimeline.test.tsx` cases.
They cover real calculations and click behavior; they do not establish visual fidelity.
Cursor's `turn-usage.test.ts` and `adapter.test.ts` cover normalization, unavailable and
partial reports, subagent attribution, and emission on the terminal provider turn.

Manual acceptance: complete a new turn, open footer/response details by click, inspect
counts and missing-data states, switch model and verify recorded attribution, then
check that the footer fits narrow widths and that popovers dismiss with Escape.
