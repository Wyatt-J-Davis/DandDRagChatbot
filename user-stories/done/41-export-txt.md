# Issue 41: `/notes/export/txt` endpoint + Flutter TXT save dialog

## What to build

Add a GET `/notes/export/txt` endpoint that returns the note content as a plain-text file download. Flutter opens a native save dialog and writes the returned bytes to the chosen path.

## Acceptance criteria

- [ ] GET `/notes/export/txt` returns file bytes with `Content-Type: text/plain` and a suggested filename
- [ ] Flutter "Export TXT" button opens the native Windows save dialog filtered to `.txt`
- [ ] The file is written to the user-selected path
- [ ] If the save dialog is cancelled, no file is written
- [ ] Endpoint is covered by a `TestClient` test asserting the response content type and body

## Blocked by

- Issue 35: Notes auto-save (content exists in `editor_notes.txt`)
