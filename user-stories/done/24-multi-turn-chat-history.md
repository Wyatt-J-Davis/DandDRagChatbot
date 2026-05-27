# Issue 24: Multi-turn chat history in conversation view

## What to build

Accumulate all messages from the current session in the conversation view so the user can follow the full context of the exchange. Messages persist for the lifetime of the app session (not across restarts).

## Acceptance criteria

- [ ] Each submitted question and its response are appended to the conversation list
- [ ] All prior messages remain visible as new ones are added
- [ ] Conversation list is not cleared between questions within the same session
- [ ] Scroll position moves to the newest message after each response

## Blocked by

- Issue 23: Chat bubble UI
