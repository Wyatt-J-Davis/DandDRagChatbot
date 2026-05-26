# Issue 14: Designate note-taker from party member list

## What to build

Add a mechanism on each party member list item to designate that member as the note-taker. Only one member can be the note-taker at a time. The designation is stored in `AppStateNotifier`.

## Acceptance criteria

- [ ] Each party member list item has a visible note-taker toggle or radio control
- [ ] Selecting a note-taker deselects the previous one
- [ ] The current note-taker is visually distinguished in the list
- [ ] Note-taker designation is stored in `AppStateNotifier`

## Blocked by

- Issue 13: Add party member to list
