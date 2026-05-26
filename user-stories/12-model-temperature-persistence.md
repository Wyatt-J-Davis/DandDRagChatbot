# Issue 12: Model + temperature persistence to `user_data.json`

## What to build

Persist the selected model and temperature value to `user_data.json` so they survive app restarts. On startup, load them back into `AppStateNotifier`.

## Acceptance criteria

- [ ] When the user changes the model selection, it is written to `user_data.json`
- [ ] When the user changes the temperature, it is written to `user_data.json`
- [ ] On app startup, the saved model and temperature are loaded and pre-populate the sidebar controls
- [ ] If `user_data.json` does not exist or the values are missing, sensible defaults are used without error

## Blocked by

- Issue 9: Flutter model selector dropdown
- Issue 11: Temperature slider
