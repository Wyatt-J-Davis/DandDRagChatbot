# 07 — Anthropic campaign summaries

Triage: ready-for-agent · Type: AFK

## Parent

[PRD — Claude (Anthropic) Provider + Dynamic Model Dropdown](CompletePRDs/PRD-ClaudeProvider.md)

## What to build

Make the campaign summary page work under the Anthropic provider, with the same thinking/cost guard the OpenAI summarizer has.

End-to-end: with Anthropic selected and a key entered, the user generates a campaign summary and the map-reduce summarizer completes reliably without hanging or running up an unbounded bill on a Claude thinking model.

- The summary page's `load_model` call passes the active provider and its key (via the shared model-options module already wired in the prior slices).
- The `disable_thinking=True` path maps, for Anthropic, to a hard `max_tokens` cap (`_SUMMARY_MAX_PREDICT`, 4096) with no `thinking` parameter passed — relying on `ChatAnthropic`'s thinking-off default so it's safe across every listable model. The OpenAI `disable_thinking` path is unchanged.

## Acceptance criteria

- [ ] Generating a campaign summary under Anthropic works end-to-end and produces a summary.
- [ ] The Anthropic summary path applies the `max_tokens` cap and passes no `thinking` config; the map-reduce does not hang.
- [ ] The OpenAI summary path (reasoning_effort + max_completion_tokens) is unchanged.
- [ ] The summary page uses the same provider/key/model source as the chat page (no divergent Model Options).
- [ ] Unit tests: `LLMHandler` Anthropic `disable_thinking` sets the `max_tokens` cap and no thinking config; summary-page test covers provider-aware model loading. Green via `venv\Scripts\python.exe -m pytest tests/ -v`.

## Blocked by

- 06 — Anthropic chat backend + dynamic model list
