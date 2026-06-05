# Issue 88: Backend: Non-blocking rotating console log and disabled access log

**Type:** AFK

## Parent

`Issues.md` ("Intermittent python backend failure")

## What to build

The packaged backend currently freezes its entire event loop after a few requests because
uvicorn writes a console log line to a stdout/stderr OS pipe that nothing drains; once the
pipe buffer fills, the next write blocks forever and every endpoint dies until restart. This
was confirmed by a `py-spy` dump showing the event loop parked permanently in logging's
`flush()` on a console `StreamHandler`.

Fix the producer side at the source so the backend can never block on console output,
regardless of who launched it:

- At startup, redirect the process's standard output and standard error to a **size-rotating
  file** in the app's data directory. The target writes to a regular file, so a write can
  never block on a full buffer. The redirect must apply to the packaged executable path; the
  dev path (running the server directly with a real console) is left unchanged.
- Start the server with the per-request access log disabled. Per-request HTTP logging already
  exists in the request-logging middleware that writes the operation log, so the uvicorn
  access log is redundant and is the dominant source of console-output volume.

The existing operation log (HTTP request lines and heavy-operation start/end/lock lifecycle)
must keep working unchanged.

See `PRD.md` ("Fix backend whole-process freeze caused by undrained stdout/stderr pipe") for
the high-level design choices, the proven root cause, and the diagnostic method.

## Acceptance criteria

- [ ] The backend redirects stdout/stderr to a rotating file under the app's data directory at startup
- [ ] A large volume of console writes completes without blocking the process
- [ ] The rotating console log is size-bounded (it rotates and cannot grow without bound)
- [ ] The server is started with the per-request access log disabled
- [ ] The existing operation log (HTTP lines and heavy-operation lifecycle) is unchanged
- [ ] Running the server directly in development (real console) still behaves as before
- [ ] A regression test proves high-volume console writes do not block and the file rotates
- [ ] A test asserts the server is started with the access log disabled
- [ ] Manual check: the rebuilt packaged app survives extended use (many Q&A questions and note saves in one session) without the backend freezing
- [ ] All tests pass (`run_tests.bat`) and the app smoke-tests without runtime exceptions

## Blocked by

- None - can start immediately
