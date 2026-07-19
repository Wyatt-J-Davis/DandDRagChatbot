# Slice 3 — Friendly error surfacing

Type: AFK · Source: PRD-OpenAIKey.md

## What to build

When an OpenAI call fails, the user sees a short, readable message instead of a raw stack trace. Since we do not validate the key up front, the first real call is where a bad key, a rate limit, or a network problem surfaces — so error translation is centralized in `LLMHandler.invoke_model`.

`invoke_model` wraps the chain invocation and catches OpenAI authentication, rate-limit, and connection errors, re-raising them as `ValueError` with user-facing messages (bad key → "check your key in Model Options"; rate limit → "try again"; network → generic connectivity message). The chat flow (`__process_chat`) and the summary flow (`CampaignSummarizer`) display that message via `st.error`/toast rather than letting the exception bubble up.

## Acceptance criteria

- [ ] An invalid API key produces a friendly "key was rejected" message in the chat UI, not a stack trace.
- [ ] A rate-limit error produces a friendly "try again" message.
- [ ] A network/connection error produces a friendly connectivity message.
- [ ] The same friendly messages surface in the summary generation flow.
- [ ] `invoke_model` raises `ValueError` (with distinct readable text per error class) for auth, rate-limit, and connection failures.
- [ ] Tests assert the error-translation behavior for each error class.

## Blocked by

- Slice 1 — OpenAI chat backend + key field + temperature removal.
