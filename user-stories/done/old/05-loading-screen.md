# Issue 5: Loading screen while backend initializes

## What to build

The root widget awaits `BackendService.ready` before rendering the main shell. While waiting, display a loading screen so the user knows the app is starting rather than frozen.

## Acceptance criteria

- [ ] On launch, a loading screen is shown immediately (before the backend is ready)
- [ ] Loading screen includes a visible spinner or progress indicator and a status label (e.g. "Starting backend…")
- [ ] Once `BackendService.ready` resolves, the loading screen is replaced by the main shell
- [ ] If the backend fails to start within a timeout, an error message is shown instead of hanging indefinitely

## Blocked by

- Issue 4: `BackendService` spawn + health poll
