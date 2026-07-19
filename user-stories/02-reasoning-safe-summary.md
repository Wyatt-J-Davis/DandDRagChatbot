# Slice 2 — Reasoning-safe summary generation

Type: AFK · Source: PRD-OpenAIKey.md

## What to build

A user generates a campaign summary using their OpenAI key, and the hierarchical map-reduce summarizer completes reliably without hanging or running up an unbounded bill. Because all supported models are GPT-5 reasoning models, the summarizer must constrain reasoning so the models don't emit unbounded reasoning traces.

The existing `disable_thinking` path in `LLMHandler.load_model` is mapped to OpenAI reasoning controls: `reasoning_effort="minimal"` plus a `max_completion_tokens` cap (replacing the old Ollama `num_predict=-1` / `reasoning=False`). `CampaignSummarizer` passes the session API key into its `load_model` call. `SummaryHandler`'s chunk sizing continues to use `get_context_tokens()` (the 16384 clamp) unchanged.

## Acceptance criteria

- [ ] `load_model(..., disable_thinking=True)` produces a `ChatOpenAI` configured with `reasoning_effort="minimal"` and a bounded `max_completion_tokens`.
- [ ] `CampaignSummarizer` threads `st.session_state.openai_api_key` into its `load_model` call.
- [ ] Generating a summary over multi-chunk notes runs the full map-reduce (map → reduce passes → final synthesis) to completion and writes `data/campaign_summary.json`.
- [ ] The summarizer does not hang and the reduction loop still converges (existing non-convergence guards remain intact).
- [ ] Tests cover the `disable_thinking` → `reasoning_effort`/`max_completion_tokens` mapping; `test_summary_handler.py` assertions updated for the OpenAI surface and passing.

## Blocked by

- Slice 1 — OpenAI chat backend + key field + temperature removal.
