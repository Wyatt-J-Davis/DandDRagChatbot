# Issue 82: Backend: Per-LLM-call timeout that aborts and releases the lock

**Type:** AFK

## What to build

Every LLM invocation must be bounded by a wall-clock timeout. When a call exceeds the timeout, the
operation aborts, the global lock is released, and an error is surfaced to the client — so a wedged
generation becomes a visible, recoverable error instead of a permanent hang.

The timeout is per LLM call (not per whole operation) so the multi-call summary map-reduce pipeline
is not penalized. The target value is ~180s, set comfortably above the normal 20–60s Q&A latency so
real generations are never cut off — only genuinely wedged ones.

This and the global lock (Issue 80) are interdependent: the lock without a timeout merely relocates
the wedge from "thread pool exhausted" to "lock held forever." Both must ship together before
release.

See `PRD.md` ("Per-LLM-call timeout — ~180s, releases the lock") for high-level design choices.

## Acceptance criteria

- [ ] Each LLM invocation is bounded by a wall-clock timeout (~180s target)
- [ ] On timeout the operation aborts, the global lock is released, and an error is returned to the
      client
- [ ] The timeout applies per LLM call, so a multi-call summary is not penalized by a single
      whole-operation budget
- [ ] A normal-length generation well within the budget completes without being cut off
- [ ] A test with a mocked LLM that hangs past the timeout proves the operation aborts, returns an
      error, AND releases the lock so a subsequent request succeeds
- [ ] All tests pass (`run_tests.bat`) and the app smoke-tests without runtime exceptions

## Blocked by

- Issue 80 (Backend: Serialize heavy operations behind a global lock with busy-rejection)
