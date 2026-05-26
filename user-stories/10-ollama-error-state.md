# Issue 10: Ollama unreachable error state

## What to build

When `/models` returns an empty list or an error (indicating Ollama is not running or has no models), display a clear, user-facing error message in the sidebar so the user understands why the app is not responding — rather than showing a broken or blank UI.

## Acceptance criteria

- [ ] If `/models` returns an empty array, a visible error message is shown in the sidebar (e.g. "No models found. Is Ollama running?")
- [ ] If `/models` returns an HTTP error or the request times out, a similar error message is shown
- [ ] Error message does not crash the app or leave the UI in an indeterminate state
- [ ] The user can retry (e.g. a refresh button or reloading the dropdown) without restarting the app

## Blocked by

- Issue 9: Flutter model selector dropdown
