# Issue 66: Flutter: Restore note taker selection on startup

**Type:** AFK

## What to build

Fix the note taker selection not persisting across application restarts. Party member names are already saved to and loaded from the backend `/party` endpoint on startup, but the note taker designation (which party member is selected as the note taker) is discarded during the load step.

The backend `/party` GET response already includes a `note_taker` boolean per member. Update `PartyService.fetchPartyMembers` to also extract the name of the member whose `note_taker` field is `true`, and return it alongside the member list. Update the startup loading logic in `MainShell` to call `setNoteTaker` with the restored value.

See `PRD.md` ("Flutter: Note taker persistence on startup") for high-level intent.

## Acceptance criteria

- [ ] After setting a note taker and restarting the app, the previously selected note taker is pre-selected in the settings popup
- [ ] If no note taker was designated, the selection remains unset after restart
- [ ] Party member names continue to load correctly alongside the note taker
- [ ] `PartyService` is covered by a test asserting that the note taker name is returned when the backend response includes `note_taker: true` on a member

## Blocked by

None — can start immediately
