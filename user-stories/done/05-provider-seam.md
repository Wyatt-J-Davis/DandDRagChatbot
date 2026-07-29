# 05 — Provider seam (OpenAI-preserving refactor)

Triage: ready-for-agent · Type: AFK

## Parent

[PRD — Claude (Anthropic) Provider + Dynamic Model Dropdown](CompletePRDs/PRD-ClaudeProvider.md)

## What to build

Introduce a `provider` dimension through the `LLMHandler` seam and extract the shared model-options logic, without changing any user-visible behavior yet beyond a new Provider selector that only offers OpenAI.

End-to-end: OpenAI chat and campaign summaries keep working exactly as today, but now every path flows through a provider-aware interface, so the Anthropic backend can be added on top in the next slice without touching the pages again.

- `LLMHandler` gains a `provider` argument on `load_model` and provider awareness in `invoke_model`'s friendly-error translation, `get_available_models`, and a new stateless `fetch_available_models(provider, api_key)`. For OpenAI, `fetch_available_models` returns the existing curated list with no network call. `is_thinking_model` and `get_context_tokens` keep their current behavior (True for supported models; flat 16384 clamp).
- A new Streamlit-free shared model-options module encapsulates provider state, per-provider key routing, session-cached model list, and persisted-model validation. In this slice it only exercises the OpenAI path (curated list, immediate validation).
- Both `TTRPGChatbot` and `CampaignSummarizer` route their "Model Options" through the shared module and render a Provider selector above the key field. Only OpenAI is selectable/functional; the summary page's duplicated key field is unified through the shared module.

## Acceptance criteria

- [ ] `LLMHandler.load_model` takes a `provider` argument and constructs the OpenAI backend when provider is OpenAI; existing OpenAI chat and summary still work end-to-end.
- [ ] `get_available_models(provider)` and `fetch_available_models(provider, api_key)` exist; the OpenAI path returns the curated hardcoded list with no network call.
- [ ] `invoke_model` friendly-error messages are provider-aware (OpenAI messages unchanged in wording for the OpenAI path).
- [ ] A shared, Streamlit-free model-options module exists and is consumed by both the chat and summary pages; the pages no longer duplicate provider/key/model logic.
- [ ] A Provider selector renders on both pages with OpenAI selected; no regression in OpenAI key gating, model preselection, persistence, or startup validation.
- [ ] Unit tests: `LLMHandler` OpenAI-through-provider-API; shared module OpenAI path (curated list + immediate validation); pages still gate on the OpenAI key. Run green via `venv\Scripts\python.exe -m pytest tests/ -v`.

## Blocked by

- None — can start immediately
