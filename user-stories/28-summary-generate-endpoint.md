# Issue 28: `/summary/generate` SSE endpoint

## What to build

Add a POST `/summary/generate` endpoint that streams SSE progress events from `SummaryHandler.generate_summary_streaming()`, including map phase, reduce phase, and final synthesis progress messages.

## Acceptance criteria

- [ ] POST `/summary/generate` accepts a JSON body with `model` (string) and `party_members` (list of strings) fields
- [ ] Streams SSE events with phase labels (e.g. `"message": "Map phase: summarizing chunk 2/5"`)
- [ ] Emits a final `{"done": true, "progress": 100}` event when complete
- [ ] Returns an SSE error event if `SummaryHandler` raises
- [ ] `SummaryHandler` is injected as a dependency
- [ ] SSE sequence covered by an `httpx.AsyncClient` test

## Blocked by

- Issue 1: FastAPI skeleton
