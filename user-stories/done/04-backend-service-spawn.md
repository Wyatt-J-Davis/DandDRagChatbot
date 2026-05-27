# Issue 4: `BackendService`: spawn Python process + poll `/health` until ready

## What to build

Implement a `BackendService` class in Flutter that spawns the Python/FastAPI backend as a child process, polls GET `/health` on a short interval until it responds successfully, and exposes a `Future<void> ready` that resolves when the backend is up. Also handles terminating the child process when the Flutter app disposes.

## Acceptance criteria

- [ ] `BackendService.start()` launches the backend executable as a child process
- [ ] Polls `/health` every 500ms until a 200 response is received
- [ ] `BackendService.ready` future completes after the first successful health check
- [ ] Calling `BackendService.dispose()` terminates the child process
- [ ] Unit tested with a mock HTTP server (see Issue 48)

## Blocked by

- Issue 2: `/health` endpoint
- Issue 3: Flutter project scaffold
