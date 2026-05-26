# Issue 47: FastAPI route tests: `/summary/generate`, `/summary`, `/notes/*`

## What to build

Write `TestClient` and `httpx.AsyncClient` tests for the summary and notes endpoint group.

## Acceptance criteria

- [ ] `/summary/generate` SSE test asserts correct phase-labeled progress events and terminal `done: true` event
- [ ] GET `/summary` test asserts summary content and metadata fields are returned
- [ ] GET `/summary` test asserts graceful empty/404 response when no summary exists
- [ ] GET `/notes` test asserts content is returned when `editor_notes.txt` exists
- [ ] GET `/notes` test asserts empty content returned when file is absent
- [ ] POST `/notes` test asserts file is written and 200 returned
- [ ] `/notes/vectorize` SSE test asserts correct progress sequence and terminal event
- [ ] GET `/notes/export/txt` test asserts `text/plain` content type and non-empty body
- [ ] GET `/notes/export/docx` test asserts correct DOCX content type and non-empty body
- [ ] All handler/file dependencies are mocked

## Blocked by

- Issue 28: `/summary/generate` SSE endpoint
- Issue 30: GET `/summary` endpoint
- Issue 35: POST `/notes` endpoint
- Issue 36: GET `/notes` endpoint
- Issue 39: `/notes/vectorize` SSE endpoint
- Issue 41: `/notes/export/txt` endpoint
- Issue 42: `/notes/export/docx` endpoint
