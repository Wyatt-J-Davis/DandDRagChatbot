# Issue 92: Flutter: Recent chat history list

**Type:** AFK

## What to build

Populate the sidebar's history region with the recent (non-archived) conversations and wire up navigation between them.

Render conversations as a flat, newest-first list (no date-group headers), each row showing the conversation title. Add a `+ New chat` button that resets the Q&A view to the welcome/empty state without writing a new entry (the conversation is still created only when the first question is sent, per Issue 90).

Clicking a conversation in the list sets it as the active conversation **and** switches the selected page to Q&A (even when the user is currently on Summary or Note Editor), loading its messages and reference chips. The currently open conversation is highlighted in the list. On startup, the Q&A page opens to the welcome/empty state (no auto-reopen of the last conversation).

See `PRD.md` ("Chat History & Collapsible Menu Sidebar") for high-level implementation details.

## Acceptance criteria

- [ ] Recent non-archived conversations appear in the sidebar, flat and sorted newest-first by `updatedAt`
- [ ] `+ New chat` clears the Q&A view to the welcome state and writes no entry until a question is sent
- [ ] Clicking a conversation switches to the Q&A page and loads its messages and reference chips
- [ ] Asking a question inside a reopened conversation appends to it and moves it to the top of the list
- [ ] The currently open conversation is visually highlighted in the list
- [ ] App startup shows the Q&A welcome/empty state with no active conversation
- [ ] Backend (`api/main.py`) is unchanged

## Blocked by

- Issue 90 (conversation persistence backbone)
- Issue 91 (collapsible sidebar shell)
