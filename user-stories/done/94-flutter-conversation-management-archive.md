# Issue 94: Flutter: Conversation management (rename, archive, delete)

**Type:** AFK

## What to build

Give each conversation row a hover-revealed `⋯` overflow menu with management actions, and add a dedicated Archived section.

Actions:
- **Rename** — override the auto-title with a custom name; set `titleOverridden` so the first-question auto-title logic never overwrites it later.
- **Archive / Unarchive** — toggle the `archived` flag. Archived conversations are exempt from the 14-day prune (Issue 93) and move into a collapsible **Archived** section at the bottom of the sidebar, separate from the recent list. Unarchiving returns the conversation to the recent (prunable) list.
- **Delete** — remove the conversation from the list and from `chat_history.json`, behind a confirmation dialog. Delete works on archived conversations too.

The Archived section is collapsible and lists archived conversations regardless of their age.

See `PRD.md` ("Chat History & Collapsible Menu Sidebar") for high-level implementation details.

## Acceptance criteria

- [ ] Each conversation row reveals a `⋯` overflow menu on hover with Rename, Archive/Unarchive, and Delete
- [ ] Rename updates the title and sets `titleOverridden`, so sending further messages does not revert the title
- [ ] Archiving moves a conversation into a collapsible "Archived" section and exempts it from the 14-day prune
- [ ] Unarchiving returns the conversation to the recent list
- [ ] Delete shows a confirmation dialog and, on confirm, removes the conversation from the list and `chat_history.json`
- [ ] Delete works on archived conversations
- [ ] Backend (`api/main.py`) is unchanged

## Blocked by

- Issue 92 (recent chat history list)
- Issue 93 (14-day conversation retention prune)
