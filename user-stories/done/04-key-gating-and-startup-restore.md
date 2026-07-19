# Slice 4 — Key gating + startup restore

Type: AFK · Source: PRD-OpenAIKey.md

## What to build

The app clearly gates key-dependent actions and behaves correctly across sessions given that the key is session-only.

Gating: with no API key entered, chat input and summary generation are disabled behind an info banner instructing the user to enter their key; note upload and vectorization remain allowed with no key (embeddings are local). The model dropdown always renders.

Startup restore: on startup the saved `model_name` is restored into session state, but the eager `load_model` call is skipped when no key is present — the model is constructed later on the first run where a restored model name and a session key coexist. If the saved `model_name` is not in the hardcoded list, it is cleared and the user is prompted to reselect (replacing the old "no longer available in Ollama" warning).

## Acceptance criteria

- [ ] With no key present, chat input and summary generation are disabled and an info banner tells the user to enter their key.
- [ ] With no key present, note upload/vectorization still works end-to-end.
- [ ] On startup with a saved `model_name` and no key, the app does not attempt to construct a model and does not error.
- [ ] Once a key is entered in a session with a restored `model_name`, the model loads and chat/summary become available.
- [ ] A saved `model_name` not in the hardcoded list is cleared with a prompt to reselect.
- [ ] `model_name` still persists across sessions; the API key is never persisted.
- [ ] Tests in `test_chatbot_unit.py` / `test_streamlit_app.py` are updated for the new gating and startup behavior and pass.

## Blocked by

- Slice 1 — OpenAI chat backend + key field + temperature removal.
