# Issue 16: Party member persistence: GET/POST `/party` + `user_data.json`

## What to build

Add GET and POST `/party` endpoints to the FastAPI app backed by `user_data.json`. Flutter saves the party roster (names + note-taker) via POST on every change and loads it via GET on startup.

## Acceptance criteria

- [ ] GET `/party` returns the current party list and note-taker from `user_data.json`
- [ ] POST `/party` writes the updated party list and note-taker to `user_data.json`
- [ ] On app startup, party data is fetched and pre-populates the sidebar list
- [ ] Both endpoints are covered by `TestClient` tests with file I/O mocked
- [ ] If `user_data.json` does not exist, GET `/party` returns an empty list without error

## Blocked by

- Issue 13: Add party member to list
- Issue 14: Designate note-taker
- Issue 15: Remove party member
