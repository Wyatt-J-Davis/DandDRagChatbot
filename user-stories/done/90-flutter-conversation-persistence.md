# Issue 90: Flutter: Conversation persistence backbone

**Type:** AFK

## What to build

Introduce the concept of a persisted **conversation** so chat survives an app restart, and make the Q&A page render the active conversation.

Add a `Conversation` model (`id`, `title`, `createdAt`, `updatedAt`, `archived`, `titleOverridden`, and an ordered list of messages) with JSON (de)serialization. Persisted messages must carry their text, sender, and `sources` (content + optional date) so reference chips survive a round-trip.

Add a `ConversationStore` service that loads/saves the full conversation list to a local `chat_history.json` (relative path, alongside `user_data.json`), mirroring `UserPreferencesService` — including graceful fallback to an empty list on a missing or corrupt file.

Update `AppStateNotifier` to hold an "active conversation" concept: the current flat `_chatHistory` becomes the active conversation's messages. A conversation is **created on the first message sent** (its title derived from the first user question, unless `titleOverridden`); appending a message bumps `updatedAt`. State changes are persisted through `ConversationStore`.

This slice does not add any sidebar UI — it is verifiable via the on-disk file and unit tests. The `archived` and `titleOverridden` fields exist now (defaults: `false`) so later slices can build on them.

See `PRD.md` ("Chat History & Collapsible Menu Sidebar") for high-level implementation details.

## Acceptance criteria

- [ ] A `Conversation` model serializes/deserializes to JSON, including messages with their `sources` and dates
- [ ] `ConversationStore` writes the conversation list to a local `chat_history.json` and reads it back; missing/corrupt file yields an empty list (no crash)
- [ ] Sending the first question creates a conversation whose title is derived from that question
- [ ] Each subsequent message in the active conversation updates `updatedAt`
- [ ] The Q&A page renders the active conversation's messages (welcome/empty state when there is no active conversation)
- [ ] Conversation data is present in `chat_history.json` after the app is closed and reopened
- [ ] Backend (`api/main.py`) is unchanged

## Blocked by

None — can start immediately
