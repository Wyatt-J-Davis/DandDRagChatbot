# Issue 48: Flutter unit tests: `BackendService` (mock HTTP server)

## What to build

Write Flutter unit tests for `BackendService` using a mock HTTP server to verify the startup polling logic and process lifecycle without spawning a real backend.

## Acceptance criteria

- [ ] Test asserts that `BackendService.ready` resolves after the mock server returns HTTP 200 on `/health`
- [ ] Test asserts that polling retries if `/health` returns a non-200 before eventually succeeding
- [ ] Test asserts that `dispose()` sends a termination signal to the child process
- [ ] Tests use a mock HTTP server — no real process is spawned

## Blocked by

- Issue 4: `BackendService` spawn + health poll
