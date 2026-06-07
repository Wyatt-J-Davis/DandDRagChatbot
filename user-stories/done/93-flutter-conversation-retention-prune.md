# Issue 93: Flutter: 14-day conversation retention prune

**Type:** AFK

## What to build

Automatically clear stale conversations so the history stays relevant.

Add a pure prune function that, given the conversation list and a "now" timestamp, removes every **non-archived** conversation whose `updatedAt` is older than 14 days. Archived conversations are always retained regardless of age. Keeping this as a standalone pure function makes it trivially unit-testable.

Invoke the prune on load (after `ConversationStore` reads the file) and write the pruned result back to disk, so expired conversations are gone before the UI ever sees them. The cutoff is keyed on `updatedAt` (last activity), so a conversation the user keeps returning to never expires.

See `PRD.md` ("Chat History & Collapsible Menu Sidebar") for high-level implementation details.

## Acceptance criteria

- [ ] A pure prune function removes non-archived conversations idle for more than 14 days
- [ ] Archived conversations are retained regardless of age
- [ ] A conversation updated within the last 14 days is retained
- [ ] The cutoff is keyed on `updatedAt`, not `createdAt`
- [ ] Prune runs on load and the pruned result is persisted back to `chat_history.json`
- [ ] Backend (`api/main.py`) is unchanged

## Blocked by

- Issue 90 (conversation persistence backbone)
