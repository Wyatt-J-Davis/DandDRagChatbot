# Issue 36: GET `/notes` endpoint + load notes on editor open

## What to build

Add a GET `/notes` endpoint that reads `editor_notes.txt` and returns its content. Flutter loads the saved content into the Quill editor when the Note Editor page is opened.

## Acceptance criteria

- [ ] GET `/notes` returns HTTP 200 with a JSON body containing the `content` string from `editor_notes.txt`
- [ ] Returns an empty content string (not an error) if `editor_notes.txt` does not exist
- [ ] Flutter fetches GET `/notes` when the Note Editor page opens and populates the Quill editor
- [ ] Endpoint is covered by a `TestClient` test

## Blocked by

- Issue 1: FastAPI skeleton
