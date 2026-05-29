# Issue 52: Persist canonical notes on vectorize (summary fix + editor unification)

**Type:** AFK

## What to build

Establish one canonical notes body that the whole app shares. Whenever notes are vectorized — from a file upload on the Q&A page or from edit-and-vectorize in the note editor — the backend persists both the raw-notes structure (consumed by the summarizer) and the editor notes text. The note editor loads this canonical text on launch, uploaded files flow into the editor (overwriting existing content is acceptable), and the now-irrelevant Import button is removed.

This fixes the "Raw notes not found" summary error (raw notes were never written by the API path) and makes vectorized notes appear in the editor automatically.

See `PRD.md` ("Notes unification", "Backend modules", user stories 3–7, 17) for high-level decisions.

## Acceptance criteria

- [ ] After `/upload-notes` succeeds, both the raw-notes structure and the editor notes text are persisted
- [ ] After `/notes/vectorize` succeeds, both the raw-notes structure and the editor notes text are persisted
- [ ] Generating a summary succeeds whenever notes have been vectorized (no "Raw notes not found")
- [ ] The note editor loads the canonical notes text on launch
- [ ] Uploading a file on the Q&A page populates the editor body with that file's text (overwrite allowed)
- [ ] The Import button is removed from the note editor
- [ ] Backend persistence behavior is covered by tests (raw-notes + editor-notes written on vectorize)

## Blocked by

- None - can start immediately
