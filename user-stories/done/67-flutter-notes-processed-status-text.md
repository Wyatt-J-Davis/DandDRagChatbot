# Issue 67: Flutter: Notes status text ("Notes processed")

**Type:** AFK

## What to build

Fix the notes status text in the settings upload area so it never shows incorrect information:

- The text "No notes loaded" must not appear while an upload or vectorize operation is actively running.
- After any vectorization completes — whether triggered from the settings upload flow or from the note editor's Vectorize button — the status text should read "Notes processed".
- Completing a vectorize operation from the note editor should also mark notes as available in app state, so the settings panel reflects the correct state regardless of which path was used.

Currently, `OperationManager` sets `hasNotes = true` only in the upload-done handler. Add the same call to the vectorize-done handler.

See `PRD.md` ("Flutter: Notes status text logic") for high-level intent.

## Acceptance criteria

- [ ] While an upload or vectorize operation is running, no status text is visible in the settings upload area
- [ ] After vectorizing from the settings upload flow, the status text reads "Notes processed"
- [ ] After vectorizing from the note editor's Vectorize button, the status text in the settings panel reads "Notes processed"
- [ ] Before any notes have been vectorized, the status text reads "No notes loaded"
- [ ] `OperationManager` test covers that `hasNotes` becomes `true` after a vectorize-done event (not only after an upload-done event)

## Blocked by

None — can start immediately
