# Issue 84: Backend: Rotating operation log for post-hoc diagnosis

**Type:** AFK

## What to build

The backend must write a rotating log file (under the app's data directory) so that any future
anomaly is diagnosable after the fact, without reproducing it live. The log records, per operation:

- operation start, end, and duration
- global-lock acquire and release
- every timeout, including a dump of the stuck call's stack
- full tracebacks on error

This is the "instrument" half of the work: the spawned backend process currently has no logging, so
when it wedges there is no trail. One retrievable log file is the primary diagnostic artifact.

Sequenced after the global lock (Issue 80) and the per-LLM-call timeout (Issue 82) so it can record
the lock and timeout events those slices introduce.

See `PRD.md` ("Backend operation log") for high-level design choices.

## Acceptance criteria

- [ ] The backend writes to a rotating log file under the app's data directory
- [ ] Each heavy operation logs its start, end, and duration
- [ ] Global-lock acquire and release are logged
- [ ] Every timeout is logged, including a dump of the stuck call's stack
- [ ] Exceptions are logged with full tracebacks
- [ ] The log rotates so it cannot grow without bound
- [ ] All tests pass (`run_tests.bat`) and the app smoke-tests without runtime exceptions

## Blocked by

- Issue 80 (Backend: Serialize heavy operations behind a global lock with busy-rejection)
- Issue 82 (Backend: Per-LLM-call timeout that aborts and releases the lock)
