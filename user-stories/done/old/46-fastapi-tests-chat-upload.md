# Issue 46: FastAPI route tests: `/chat`, `/upload-notes` SSE sequences

## What to build

Write `httpx.AsyncClient` tests for the `/chat` and `/upload-notes` SSE endpoints, asserting the correct event sequence including intermediate progress events and the terminal `done: true` event.

## Acceptance criteria

- [ ] `/upload-notes` test asserts at least one `done: false` progress event followed by a `done: true` terminal event
- [ ] `/upload-notes` test asserts an SSE error event is emitted (not HTTP 500) when `DatabaseHandler` raises
- [ ] `/chat` test asserts the terminal event contains `answer` and `sources` fields
- [ ] `/chat` test asserts an SSE error event is emitted when `LLMHandler` raises
- [ ] All handler dependencies are mocked — no real Ollama or disk I/O in tests

## Blocked by

- Issue 18: `/upload-notes` SSE endpoint
- Issue 22: `/chat` SSE endpoint
