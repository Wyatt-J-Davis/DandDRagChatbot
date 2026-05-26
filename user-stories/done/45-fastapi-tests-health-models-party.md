# Issue 45: FastAPI route tests: `/health`, `/models`, `/party`

## What to build

Write `TestClient` tests for the `/health`, `/models`, and `/party` endpoints. Handlers are mocked at the dependency injection boundary so tests are fast and isolated.

## Acceptance criteria

- [ ] GET `/health` test asserts HTTP 200 and `{"status": "ok"}` body
- [ ] GET `/models` test asserts correct JSON array when `LLMHandler` returns a model list
- [ ] GET `/models` test asserts empty array when `LLMHandler` returns nothing
- [ ] GET `/party` test asserts correct party data when `user_data.json` exists
- [ ] GET `/party` test asserts empty list when `user_data.json` is absent
- [ ] POST `/party` test asserts data is written and 200 returned
- [ ] All handler/file dependencies are mocked — no real Ollama or disk I/O in tests

## Blocked by

- Issue 2: `/health` endpoint
- Issue 8: `/models` endpoint
- Issue 16: Party persistence endpoints
