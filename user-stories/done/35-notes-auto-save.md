# Issue 35: Auto-save note editor content to `/notes` POST endpoint

## What to build

Add a POST `/notes` endpoint that writes content to `editor_notes.txt`. Flutter debounce-saves the editor content automatically as the user types so no work is ever lost.

## Acceptance criteria

- [ ] POST `/notes` accepts a JSON body with a `content` string field and writes it to `editor_notes.txt`
- [ ] Flutter triggers POST `/notes` after a short debounce delay (e.g. 1–2 seconds) following each edit
- [ ] Auto-save does not interrupt or interfere with the editing experience
- [ ] A subtle visual indicator (e.g. "Saved") confirms the save completed
- [ ] Endpoint is covered by a `TestClient` test

## Blocked by

- Issue 34: `flutter_quill` editor widget
