# Issue 57: Long-running operation manager (SSE survives page switches)

**Type:** HITL

## What to build

Stop long-running operations from being killed when the user switches pages. Move ownership of the SSE stream subscriptions (chat, upload, vectorize, summary) out of the page widgets and into app/notifier scope, so the HTTP connection and progress survive navigation and the result lands when complete. Returning to a page shows the operation's current progress. Chat history is held at this scope so it persists across page switches (session-only; cleared on restart).

This is the architectural change behind the user's "run operations as subprocesses" framing — keeping the connection alive at app scope prevents the backend generator from being cancelled, with no OS subprocess needed.

See `PRD.md` ("Long-running ops survive page switches", "Long-running operation manager", "Further Notes", user stories 8–10) for high-level decisions.

## Acceptance criteria

- [ ] In-progress inference continues when switching away and back; progress reflects current state on return
- [ ] In-progress vectorization continues across page switches
- [ ] In-progress summary generation continues across page switches
- [ ] Chat history remains intact when switching between pages within a session
- [ ] Chat history is cleared on app restart (session-only)
- [ ] Operation manager state transitions (idle → running → done/error) and progress/result retention independent of any page are covered by unit tests

## Blocked by

- None - can start immediately
