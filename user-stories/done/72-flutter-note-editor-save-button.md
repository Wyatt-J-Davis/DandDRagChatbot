# Issue 72: Flutter: Note Editor Save button

**Type:** AFK

## What to build

Add a Save button to the Note Editor toolbar that persists the current note content to the backend. The button sits immediately to the left of the Vectorize button. Clicking it sends the editor's plain-text content to the existing `POST /notes` endpoint and shows a `SnackBar` confirmation on success.

The button is only rendered when a `NoteContentService` is available — the same guard already used for the Export buttons.

See `PRD.md` ("Note Save Button") for high-level implementation details.

## Acceptance criteria

- [ ] A Save button appears in the Note Editor toolbar, to the left of the Vectorize button
- [ ] Clicking Save sends the current plain-text editor content to the backend
- [ ] A SnackBar confirmation is shown when the save succeeds
- [ ] The Save button is hidden when no `NoteContentService` is injected (consistent with Export button behavior)
- [ ] Saved content is present in the editor after an app restart (i.e. the backend actually persisted it)

## Blocked by

None — can start immediately
