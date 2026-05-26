# Issue 39: `/notes/vectorize` SSE endpoint

## What to build

Add a POST `/notes/vectorize` endpoint that accepts plain-text note content (Quill delta markup stripped), passes it to `DatabaseHandler` for vectorization, and streams SSE progress events.

## Acceptance criteria

- [ ] POST `/notes/vectorize` accepts a JSON body with a `content` string field (plain text, no delta markup)
- [ ] Streams SSE progress events during vectorization
- [ ] Emits a final `{"done": true, "progress": 100}` event on completion
- [ ] Returns an SSE error event if `DatabaseHandler` raises
- [ ] `DatabaseHandler` is injected as a dependency
- [ ] SSE sequence covered by an `httpx.AsyncClient` test

## Blocked by

- Issue 1: FastAPI skeleton
