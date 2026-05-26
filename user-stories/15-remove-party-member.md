# Issue 15: Remove party member from list

## What to build

Add a delete button to each party member list item so the user can remove members from the roster.

## Acceptance criteria

- [ ] Each list item has a visible delete/remove button
- [ ] Tapping the button removes that member from the list in `AppStateNotifier`
- [ ] If the removed member was the note-taker, the note-taker designation is cleared
- [ ] The list updates immediately without requiring a page refresh

## Blocked by

- Issue 13: Add party member to list
