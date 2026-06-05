# Issue 80: Backend: Serialize heavy operations behind a global lock with busy-rejection

**Type:** AFK

## What to build

All heavy backend operations (chat, summary generate, upload-notes, notes vectorize) must run one
at a time, guarded by a single global lock. When a heavy operation is already in flight and another
request arrives, the second request returns immediately with a clear "backend is busy, wait for the
current operation to finish" response instead of blocking, piling up, or deadlocking.

This is the root-cause fix for the intermittent unrecoverable hang: today the backend is a single
process with all-synchronous streaming endpoints sharing one bounded thread pool, and overlapping
heavy operations exhaust that pool / deadlock on concurrent native initialization. Serializing
matches the single-GPU reality (concurrent generations give no speedup on one GPU) and removes the
concurrency that causes the wedge.

The lock must be acquired at the start of each heavy operation and released in all exit paths
(success, error, client disconnect). Lightweight endpoints (health, status, models, notes get/save,
party, summary get, exports) are NOT gated by the lock.

**Note:** This slice alone is not full protection — a lock without a timeout merely relocates the
wedge from "thread pool exhausted" to "lock held forever." Issue 82 (per-LLM-call timeout + lock
release) completes the recovery story and must ship together with this work before release.

See `PRD.md` ("Concurrency model — serialize heavy operations" and "On contention — reject, do not
queue") for high-level design choices.

## Acceptance criteria

- [ ] A global lock guards chat, summary generate, upload-notes, and notes vectorize so only one
      runs at a time
- [ ] While a heavy operation holds the lock, a second heavy request returns a clear "backend busy"
      response immediately (it does not block or queue)
- [ ] The lock is released on every exit path (success, exception, client disconnect)
- [ ] Lightweight endpoints (health, status, models, notes get/save, party, summary get, exports)
      remain ungated and responsive while a heavy operation runs
- [ ] A test with the LLM/embeddings mocked proves that, while one heavy operation is in flight, a
      second concurrent request receives the busy response rather than blocking or deadlocking
- [ ] All tests pass (`run_tests.bat`) and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
