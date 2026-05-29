# Issue 49: Flutter unit tests: `AppStateNotifier` (model, temperature, party persistence)

## What to build

Write Flutter unit tests for `AppStateNotifier` using `ProviderContainer` to verify model selection, temperature, and party member mutations, as well as persistence round-trips to `user_data.json`.

## Acceptance criteria

- [ ] Test asserts model selection updates are reflected in state
- [ ] Test asserts temperature updates are reflected in state
- [ ] Test asserts adding a party member appends to the list
- [ ] Test asserts removing a party member removes from the list
- [ ] Test asserts designating a note-taker updates the correct field
- [ ] Test asserts state is written to `user_data.json` on mutation (file I/O mocked)
- [ ] Test asserts state is loaded from `user_data.json` on initialization (file I/O mocked)

## Blocked by

- Issue 12: Model + temperature persistence
- Issue 16: Party persistence endpoints
