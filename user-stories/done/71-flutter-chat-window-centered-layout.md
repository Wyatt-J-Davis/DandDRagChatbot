# Issue 71: Flutter: Chat window centered layout + input bubble

**Type:** AFK

## What to build

Redesign the Q&A page layout to feel focused and compact, matching the Ollama chat aesthetic, rather than stretching across the full available width.

Two changes:

**1. Width-constrained centered column.** Both the message list and the input row should be constrained to a maximum width of 720px and centered horizontally. This is consistent with the existing empty-state layout, which already applies this constraint to the welcome-screen input.

**2. Rounded input bubble.** Wrap the input `TextField` and send button in a container with a rounded border and a subtle background fill, giving the input area a clear, intentional bubble appearance.

Existing chat bubble styling (user messages right-aligned with primary color, assistant messages left-aligned with surfaceVariant color) is unchanged.

See `PRD.md` ("Flutter: Chat window layout") for high-level intent.

## Acceptance criteria

- [ ] On a wide window, the message list does not stretch beyond 720px — visible margins appear on both sides
- [ ] The message list and input row are horizontally centered within the available space
- [ ] The input area has a visible rounded border container
- [ ] The empty welcome state (wizard + input) is visually consistent with the active chat layout
- [ ] Existing chat bubble alignment and colors are unchanged
- [ ] No layout overflow on narrow windows (the constraint is a maximum, not a fixed width)

## Blocked by

None — can start immediately
