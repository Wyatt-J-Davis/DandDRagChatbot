# Issue 13: Add party member to list

## What to build

Add a text field and button in the sidebar panel that lets the user type a party member name and add it to a list. The list is rendered in the sidebar and stored in `AppStateNotifier`.

## Acceptance criteria

- [ ] Text field and "Add" button are visible in the sidebar
- [ ] Submitting a non-empty name appends it to the party member list
- [ ] The list of added names is displayed in the sidebar below the input
- [ ] Empty or whitespace-only names are rejected without error
- [ ] Party member list is stored in `AppStateNotifier`

## Blocked by

- Issue 7: Sidebar panel placeholder
