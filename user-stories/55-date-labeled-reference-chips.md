# Issue 55: Date-labeled reference chips

**Type:** AFK

## What to build

Replace the generic "source1", "source2" labels on chatbot reference chips with the date of the referenced journal entry. The chunk `Date` metadata already exists but is dropped by `/chat`, which returns only chunk content. Return each source as a structured object including its date, and label each reference chip with that date, falling back to "Source N" when the date is unknown.

See `PRD.md` ("`/chat` source payload", user story 15) for high-level decisions.

## Acceptance criteria

- [ ] `/chat` returns each source as a structured object that includes the chunk's date metadata alongside its content
- [ ] Reference chips display the source date as their label
- [ ] Chips fall back to "Source N" when a source's date is unknown
- [ ] Tapping a chip still shows the underlying source content (existing popup behavior preserved)
- [ ] `/chat` source payload shape is covered by a test (including the unknown-date case)

## Blocked by

- None - can start immediately
