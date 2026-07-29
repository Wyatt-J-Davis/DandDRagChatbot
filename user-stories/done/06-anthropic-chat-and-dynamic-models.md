# 06 — Anthropic chat backend + dynamic model list

Triage: ready-for-agent · Type: AFK

## Parent

[PRD — Claude (Anthropic) Provider + Dynamic Model Dropdown](CompletePRDs/PRD-ClaudeProvider.md)

## What to build

Make Anthropic a fully functional provider for chat, with its model dropdown populated live from the user's key.

End-to-end: the user selects Anthropic in the Provider selector, pastes their Anthropic key, the model dropdown populates from Anthropic's models endpoint, and they can ask questions about their campaign — with provider-named gating and error messages throughout.

- `LLMHandler.load_model` constructs a `langchain_anthropic.ChatAnthropic` (slotting into the existing `prompt | model | StrOutputParser` chain) when provider is Anthropic. `fetch_available_models` for Anthropic calls the Anthropic SDK models-list endpoint via `anthropic.Anthropic(api_key=...).models.list()` and returns model ids in the API's returned order. `invoke_model` translates `anthropic.*` auth/rate-limit/connection errors into provider-named `ValueError`s.
- Shared model-options module handles the Anthropic path: empty/disabled dropdown with an "enter your key" hint until a valid key is present; session-cached list refetched only when the Anthropic key value changes; index-0 preselect; per-provider session key slots (`openai_api_key`, `anthropic_api_key`) that survive provider switches; provider-aware gating on the active provider's key; `provider` persisted alongside `model_name`; deferred validation of a saved Anthropic model once the key + list are available.
- A failed Anthropic models-list call surfaces a readable provider-named message (de-facto early key validation).
- Add `anthropic` and `langchain-anthropic` to `requirements.txt`.

## Acceptance criteria

- [ ] Selecting Anthropic + entering a valid key populates the model dropdown from `/v1/models`; chat works end-to-end against Claude.
- [ ] With Anthropic active and no valid key, the dropdown is empty/disabled with a hint to enter the key; a bad key surfaces a readable provider-named message.
- [ ] The fetched Anthropic list is cached in session and refetched only when the Anthropic key changes (not every rerun).
- [ ] Each provider's key persists in its own session slot across a provider switch; neither key is written to disk.
- [ ] `provider` is persisted; a saved Anthropic model is dropped with the reselect warning if it's absent from the fetched list; a saved OpenAI model still validates immediately.
- [ ] Chat input / gating and error messages name the active provider.
- [ ] `requirements.txt` includes `anthropic` and `langchain-anthropic`.
- [ ] Unit tests: `LLMHandler` Anthropic load + fetch (success/failure) + error translation; shared module Anthropic path (empty-until-key, cache refetch-on-key-change, deferred validation, per-provider key routing); page-level provider switch + provider-aware gating. Green via `venv\Scripts\python.exe -m pytest tests/ -v`.

## Blocked by

- 05 — Provider seam (OpenAI-preserving refactor)
