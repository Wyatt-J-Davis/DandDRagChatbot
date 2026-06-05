# Issue 85: Flutter: Request timeouts on all backend calls

**Type:** AFK

## What to build

Every backend HTTP call from the Flutter front end must have a request timeout, so the UI recovers
and shows an error instead of spinning forever when the backend stops responding. Today calls such
as chat and note save have no timeout, so a hung backend leaves the UI stuck on the loading
animation indefinitely with no way to recover short of restarting.

Add a timeout to each backend call: chat, notes get/save, summary, upload, vectorize, status,
models, and exports. On timeout the corresponding operation transitions to an error state and the
user sees an actionable error rather than an indefinite spinner.

See `PRD.md` ("Front-end request timeouts") for high-level design choices.

## Acceptance criteria

- [ ] Every backend HTTP call (chat, notes get/save, summary, upload, vectorize, status, models,
      exports) has a request timeout
- [ ] When a call times out, the relevant operation enters an error state and the UI shows an error
      instead of spinning indefinitely
- [ ] Normal-latency operations within the timeout are unaffected
- [ ] A test proves a timed-out backend call surfaces as an error rather than hanging
- [ ] All Flutter tests pass and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
