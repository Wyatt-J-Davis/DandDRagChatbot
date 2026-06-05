# Issue 89: Flutter: Drain the backend process's stdout and stderr

**Type:** AFK

## Parent

`Issues.md` ("Intermittent python backend failure")

## What to build

The desktop app spawns the backend as a child process whose stdout/stderr are connected to OS
pipes that the app never reads. This undrained pipe is the consumer side of the freeze
described in Issue 88: once the buffer fills, the backend blocks forever on its next console
write. Add defense-in-depth so the pipe can never fill, independent of the backend fix.

Right after the backend process is spawned, subscribe to and discard both its standard output
and standard error streams. The process handle must still be retained for lifecycle management
(health polling and shutdown) exactly as today; only stream consumption is added.

This slice is independent of Issue 88 and can be implemented in parallel; together they fix the
freeze at both ends.

See `PRD.md` ("Fix backend whole-process freeze caused by undrained stdout/stderr pipe") for
the high-level design choices and the proven root cause.

## Acceptance criteria

- [ ] After the backend process is spawned, its stdout and stderr streams are consumed and discarded
- [ ] The process handle is still retained for health polling and shutdown (no regression in lifecycle behavior)
- [ ] A test injects a fake process whose stdout/stderr emit data and verifies those streams are drained without the start path hanging
- [ ] Existing backend-service and lifecycle tests still pass
- [ ] `flutter test` passes and the app smoke-tests without runtime exceptions

## Blocked by

- None - can start immediately (independent of Issue 88)
