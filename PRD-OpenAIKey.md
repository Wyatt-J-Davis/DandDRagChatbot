# PRD — OpenAI Key Feature

Branch: `oppen-ai-key` · Target deploy: Streamlit Community Cloud

## Problem Statement

The chatbot only works against locally-installed Ollama models. That requires every player to install Ollama, pull multi-gigabyte models, and have enough local RAM/CPU to run them. For a lightweight, publicly-hosted Community Cloud deployment that's a non-starter — there is no local Ollama runtime on Community Cloud, and asking players to run one defeats the point of a hosted app. Players want to open a URL, paste their own OpenAI API key, and start asking questions about their campaign without any local model setup.

## Solution

Replace the local Ollama LLM backend with OpenAI's hosted models. Each player supplies their own OpenAI API key at runtime through a password field in the app. The key lives only in their browser session — it is never persisted to disk, never committed as a Streamlit secret, and never shared between users, so each player pays only for their own usage. Model selection becomes a short, curated dropdown of supported OpenAI models. Everything else about the app — note upload, local vector embeddings, retrieval, the chat UX, and the campaign summarizer — works exactly as before.

## User Stories

1. As a Community Cloud user, I want to paste my own OpenAI API key into the app, so that I can use the chatbot without installing Ollama or any local model.
2. As a privacy-conscious user, I want my API key to exist only for my current session and never be written to disk, so that it can't leak from the deployed app.
3. As a user, I want my key to never be shared with other users of the same deployment, so that nobody else can spend against my OpenAI account.
4. As the app owner, I want no shared/owner-provided key baked into the deployment, so that strangers on the public URL cannot burn my OpenAI credits.
5. As a user, I want to pick which OpenAI model to use from a short curated list, so that I can trade off cost against answer quality.
6. As a cost-sensitive user, I want the cheapest supported model preselected by default, so that I incur the lowest cost unless I deliberately choose otherwise.
7. As a returning user, I want the app to remember my previously selected model, so that I don't have to reselect it every session.
8. As a user, I want to upload and vectorize my campaign notes without needing an API key, so that document ingestion works offline and for free.
9. As a user, I want to be clearly told to enter my API key before I can chat or generate a summary, so that I understand why those actions are disabled.
10. As a user who typed a bad key, I want a readable error message rather than a stack trace, so that I know to fix my key.
11. As a user who hits an OpenAI rate limit, I want a friendly "try again" message, so that I understand the failure is transient.
12. As a user with a flaky connection, I want network failures surfaced as a readable message, so that I'm not confused by a raw exception.
13. As a user, I want to generate a campaign summary using my OpenAI key, so that the map-reduce summarizer works the same as it did on Ollama.
14. As a user, I want the summarizer to not hang or run up huge bills on reasoning models, so that summary generation completes reliably and affordably.
15. As a user, I want the app to remember my model choice across sessions but still require me to re-enter my key each session, so that convenience and key-safety are both respected.
16. As a user whose saved model is no longer offered, I want the app to quietly drop it and ask me to reselect, so that a stale saved choice doesn't break startup.
17. As a maintainer, I want Ollama fully removed from the codebase on this branch, so that there is a single, clean OpenAI backend with no dead code.
18. As a maintainer, I want the OpenAI backend hidden behind the existing `LLMHandler` interface, so that `TTRPGChatbot` and `SummaryHandler` are unaffected.

## Implementation Decisions

**Provider strategy — full replacement.** Ollama is removed entirely on this branch: the `ollama` and `langchain_ollama` imports, `ollama.list()`, and `ollama.show()` probes are deleted. There is no runtime provider toggle; OpenAI is the only backend.

**`LLMHandler` remains the single seam.** Its public surface is preserved so callers don't change: `get_available_models()`, `load_model(...)`, `invoke_model(prompt, mappings)`, `get_context_tokens(model_name)`, `is_thinking_model(model_name)`. Only the internals are reimplemented against OpenAI. This keeps `LLMHandler` a deep module — a stable, testable interface hiding all OpenAI specifics.

- `get_available_models()` returns a hardcoded, verified list of supported models (no network call, no key required to render): `gpt-5.4-nano` (default/cheapest), `gpt-5.4-mini`, `gpt-5.4`.
- `is_thinking_model()` returns `True` for all supported models (they are all GPT-5 reasoning models); the `ollama.show` capability probe is removed.
- `get_context_tokens()` returns the existing `_MAX_CONTEXT_TOKENS = 16384` clamp for all models; the `ollama.show` context-length lookup is removed. The summarizer's char-based chunk sizing is unchanged.
- `load_model()` gains an explicit `api_key` parameter — signature becomes `load_model(model_name, api_key, disable_thinking=False)`. It validates `model_name` against the hardcoded list and constructs a `langchain_openai.ChatOpenAI`. Temperature is no longer accepted (see below).
- The `disable_thinking` path maps to OpenAI reasoning controls: `reasoning_effort="minimal"` plus a `max_completion_tokens` cap, replacing the old `num_predict=-1` / `reasoning=False` Ollama parameters. The summarizer continues to use this path so reasoning models can't emit unbounded traces.
- `invoke_model()` preserves the `prompt | model | StrOutputParser()` chain and centralizes friendly-error translation: OpenAI auth, rate-limit, and connection errors are caught and re-raised as `ValueError` with user-readable messages (bad key / rate limit / network) for the UI layers to display.

**API key handling — per-user, session-only.** A `st.text_input(type="password")` at the top of the sidebar "🔧 Model Options" section stores to `st.session_state.openai_api_key`. The key is never written to `user_data.json`, never placed in `secrets.toml`, and there is no shared owner-provided fallback key. The key is passed explicitly into `load_model` at every call site (`TTRPGChatbot` startup, `__process_model_options`, and `CampaignSummarizer`). No active key validation — the first real API call fails loudly through the friendly-error path.

**Temperature removed.** GPT-5 reasoning models reject any non-default `temperature` (HTTP 400 when `reasoning_effort != none`). The temperature slider is removed from the UI, and `model_temperature` is dropped from session-state initialization, `__save_user_data`, `load_model`, and `CampaignSummarizer`. A future `reasoning_effort` selector (`minimal`/`low`/`medium`/`high`) is noted as possible follow-up but is out of scope here.

**Persistence.** `model_name` continues to persist in `user_data.json`; `model_temperature` is no longer persisted. On startup, the saved `model_name` is restored into session state but the eager `load_model` call is **skipped when no key is present**; the model is constructed later on the first run where a restored model name and a session key coexist. If the saved `model_name` isn't in the hardcoded list, it is cleared with a prompt to reselect (replacing the old "no longer available in Ollama" warning).

**Gating.** With no key, chat input and summary generation are disabled behind an info banner instructing the user to enter their key. Note upload and vectorization remain allowed without a key. The model dropdown always renders (it's a static list) with `gpt-5.4-nano` preselected.

**Embeddings unchanged.** Retrieval keeps FastEmbed `BAAI/bge-base-en-v1.5` running locally. No OpenAI embeddings, no re-vectorization of existing databases, and note ingestion stays keyless.

**Dependencies.** Remove `ollama` and `langchain-ollama` from `requirements.txt`; add `openai` and `langchain-openai`. `TTRPGChatbot.spec` (PyInstaller) is updated minimally so the build doesn't break; the packaged `.exe` path is not a focus on this Community-Cloud-targeted branch.

## Testing Decisions

Tests target external behavior of the modules through their public interfaces, not internal implementation details. Written test-first per the project workflow, and run with `venv\Scripts\python.exe -m pytest tests/ -v`.

- **`conftest.py`:** replace the `ollama` / `langchain_ollama` `sys.modules` mocks with `openai` / `langchain_openai` mocks. FastEmbed, Chroma, and other existing mocks are unchanged (embeddings stay local).
- **`test_llm_handler.py` (full rewrite):** the primary deep-module test target. Cover — `get_available_models()` returns the hardcoded list; `get_context_tokens()` returns `16384`; `is_thinking_model()` returns `True` for supported models; `load_model()` validates the model name, requires/threads `api_key`, and constructs `ChatOpenAI`; the `disable_thinking` path sets `reasoning_effort="minimal"` and a `max_completion_tokens` cap; `invoke_model()` runs the chain and translates OpenAI auth/rate-limit/network errors into friendly `ValueError`s; `invoke_model()` still raises when no model is loaded.
- **`test_summary_handler.py`, `test_chatbot_unit.py`, `test_streamlit_app.py` (patched):** update assertions that assume Ollama model names, the temperature slider, or the old `load_model` signature. Prior art for these AppTest/unit patterns already exists in the current suite and is followed.

Good tests here assert the observable contract of `LLMHandler` (what parameters reach `ChatOpenAI`, what messages surface on failure) rather than reaching into private state.

## Out of Scope

- Any Ollama coexistence / provider-toggle path.
- OpenAI (or any hosted) embeddings; retrieval stays on local FastEmbed.
- A shared owner-provided API key or any `secrets.toml`-based key delivery.
- Persisting the API key in any form.
- Active key validation before first use.
- A `reasoning_effort` user control (possible follow-up).
- Serious investment in the PyInstaller `.exe` build/testing on this branch.
- Streaming true token-by-token model output (the existing post-hoc word streaming is retained).

## Further Notes

- Model pricing/lineup was verified against OpenAI's official pricing page (July 2026); only models confirmed on that page are used, to avoid shipping an id that 404s. `gpt-5.4-nano` is the cheapest verified option and is the default.
- The 400-on-temperature behavior of GPT-5 reasoning models is the reason the temperature control is removed rather than merely hidden.
- Because embeddings are local, first-run on Community Cloud still downloads the `bge-base-en-v1.5` model — unchanged from today's behavior.
