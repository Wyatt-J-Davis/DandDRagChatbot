# Issue 78: Flutter: Stop backend executable on app close

**Type:** AFK

## What to build

When the application window is closed, the backend executable (`ttrpg_backend.exe`) must be shut down as well. Today it keeps running in Task Manager after the app closes.

**Root cause:** `BackendService.dispose()` already kills the backend process and closes the HTTP client, but nothing ever calls it — the backend service created at startup is never disposed, and there is no window-close or lifecycle hook.

**Fix:** Add a small `BackendLifecycleObserver` class that implements `WidgetsBindingObserver` and holds a reference to the `BackendService`. Its `didRequestAppExit()` override calls `dispose()` and then returns `AppExitResponse.exit`. Register the observer at startup (via `WidgetsBinding.instance.addObserver(...)`) once the backend service instance exists.

`didRequestAppExit` is Flutter's built-in desktop window-close hook, so **no new package dependency** is introduced. The backend is a single PyInstaller onedir process (uvicorn in-process, no workers/reload, no bootloader child), so the existing plain `_process.kill()` inside `dispose()` is sufficient — no process-tree kill and no `taskkill` is needed. The kill must also work when the window is closed while the backend is still starting up.

See `PRD.md` ("Backend shutdown on app close") for high-level implementation details.

## Acceptance criteria

- [ ] Closing the application window stops the backend process (`ttrpg_backend.exe` disappears from Task Manager)
- [ ] The backend is stopped even when the window is closed while it is still starting up
- [ ] A `BackendLifecycleObserver` translates an app-exit request into a backend teardown and returns `AppExitResponse.exit`
- [ ] The observer is registered at startup and given the live `BackendService`
- [ ] No new third-party package dependency is added
- [ ] A unit test constructs the observer with a `BackendService` whose injected `Process` is a fake recording `kill()`, calls `didRequestAppExit()`, and asserts the process was killed and `AppExitResponse.exit` is returned
- [ ] All Flutter tests pass and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
