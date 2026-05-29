# Issue 59: Q&A welcome state + thematic nav icons

**Type:** HITL

## What to build

Give the Q&A page a polished empty state and refresh the navigation icons. When the chat message list is empty, show a centered input box with a large wizard emoji above it (like mainstream chatbot welcome screens). As soon as there is at least one message, switch to the standard bottom-docked chat layout (messages list filling the window, input docked at the bottom). The switch is a conditional show/hide on chat emptiness — no animated transition. Replace the navigation rail icons with thematic Material icons: an orb-style icon for Q&A, `Icons.auto_awesome` (AI sparkle) for Summary, and a quill-style icon for Notes.

Since chat is session-only, every fresh launch starts on the welcome state.

See `PRD.md` ("Chat", "Navigation icons", user stories 21–23) for high-level decisions.

## Acceptance criteria

- [ ] Empty chat shows a centered input with a large wizard emoji above it
- [ ] Sending the first message switches to the bottom-docked chat layout
- [ ] Welcome state reappears whenever the message list is empty (e.g. fresh launch)
- [ ] Navigation rail uses an orb-style icon (Q&A), `Icons.auto_awesome` (Summary), and a quill-style icon (Notes)

## Blocked by

- None - can start immediately
