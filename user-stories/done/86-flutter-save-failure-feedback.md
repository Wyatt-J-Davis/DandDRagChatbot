# Issue 86: Flutter: Surface save failures in the note editor

**Type:** AFK

## What to build

The note-editor save flow must give feedback on both outcomes: a confirmation on success AND an
error on failure or timeout. Today only the success path is surfaced — hitting **Save** when the
save fails (or hangs) shows nothing, so the user believes their notes are saved when they are not,
and loses work on restart.

When a save fails (non-success response) or times out, the editor shows a clear error (e.g. a
snackbar) telling the user the notes were NOT saved, so they can retry instead of silently losing
work. This depends on Issue 85 so a hung save becomes a surfaced failure rather than an indefinite
await.

See `PRD.md` ("Save feedback on both paths") for high-level design choices.

## Acceptance criteria

- [ ] A successful save shows a confirmation (existing behavior preserved)
- [ ] A failed save (non-success response) shows an error indicating the notes were not saved
- [ ] A timed-out save shows an error indicating the notes were not saved
- [ ] A Flutter widget test asserts the editor shows an error when a save fails/times out
- [ ] All Flutter tests pass and the app smoke-tests without runtime exceptions

## Blocked by

- Issue 85 (Flutter: Request timeouts on all backend calls)
