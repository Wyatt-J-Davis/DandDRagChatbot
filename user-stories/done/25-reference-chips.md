# Issue 25: Reference chips alongside assistant response

## What to build

Render a row of `ReferenceChip` widgets below each assistant `ChatBubble`, one chip per source chunk returned in the `/chat` SSE response.

## Acceptance criteria

- [ ] Each assistant bubble is followed by a row of chips labeled by source index (e.g. "Source 1", "Source 2")
- [ ] Chips are only shown when source chunks are present in the response
- [ ] Chips are visually associated with their corresponding assistant bubble
- [ ] Chips are tappable (action wired in Issue 26)

## Blocked by

- Issue 23: Chat bubble UI
