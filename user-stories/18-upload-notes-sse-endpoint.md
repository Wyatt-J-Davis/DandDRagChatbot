# Issue 18: `/upload-notes` SSE endpoint

## What to build

Add a POST `/upload-notes` endpoint that accepts an absolute file path, passes it to `DatabaseHandler.generate_database()`, and streams SSE progress events back to the client.

## Acceptance criteria

- [ ] POST `/upload-notes` accepts a JSON body with an `file_path` string field
- [ ] Streams SSE events in the shape `{"done": false, "progress": <int>, "message": "<str>"}` during processing
- [ ] Emits a final `{"done": true, "progress": 100}` event on completion
- [ ] Returns an SSE error event (not an HTTP 500) if `DatabaseHandler` raises
- [ ] `DatabaseHandler` is injected as a dependency so the route is testable in isolation
- [ ] SSE sequence is covered by an `httpx.AsyncClient` test asserting correct event order

## Blocked by

- Issue 1: FastAPI skeleton
