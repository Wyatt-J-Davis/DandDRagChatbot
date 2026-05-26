# Issue 42: `/notes/export/docx` endpoint + Flutter DOCX save dialog

## What to build

Add a GET `/notes/export/docx` endpoint that converts the note content to a DOCX file and returns it as a download. Flutter opens a native save dialog and writes the returned bytes to the chosen path.

## Acceptance criteria

- [ ] GET `/notes/export/docx` returns file bytes with `Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document` and a suggested filename
- [ ] The DOCX file is valid and openable in Word or Google Docs
- [ ] Flutter "Export DOCX" button opens the native Windows save dialog filtered to `.docx`
- [ ] The file is written to the user-selected path
- [ ] If the save dialog is cancelled, no file is written
- [ ] Endpoint is covered by a `TestClient` test asserting response content type

## Blocked by

- Issue 35: Notes auto-save (content exists in `editor_notes.txt`)
