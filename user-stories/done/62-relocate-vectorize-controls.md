# Issue 62: Relocate vectorize controls to top of editor

**Type:** AFK

## What to build

Move the intrusive vectorize controls out of the note-taking area to the top of the note editor page, beside the dark-mode toggle, so they don't crowd the writing space. Vectorization behavior is unchanged — only the placement of the control moves.

See `PRD.md` ("Note editor", user story 27) for high-level intent.

## Acceptance criteria

- [ ] Vectorize control appears at the top of the note editor, next to the dark-mode toggle
- [ ] The vectorize control no longer occupies space within the note-taking/editing area
- [ ] Triggering vectorization from the new location works and shows progress as before

## Blocked by

- Issue 52: Persist canonical notes on vectorize
