# Issue 87: Flutter: Global busy gate across pages

**Type:** AFK

## What to build

The front end must track a cross-page "busy" state that disables triggering a new heavy operation
(chat, summary, upload, vectorize) while one is already running. Today each operation's status is
tracked independently with no global gate, so the user can start a second heavy operation from
another page while the first is still running — the exact overlap that triggers the backend hang.

A global busy state, derived from whether any heavy operation is in flight, disables the controls
that would start another heavy operation until the current one finishes. This means the user rarely
reaches the backend's busy rejection in the first place. The backend rejection (Issue 80) remains
the authoritative guard against races; bespoke client handling of the busy response is out of scope
— a generic error is acceptable.

See `PRD.md` ("Global busy gate (client side)") for high-level design choices.

## Acceptance criteria

- [ ] A global busy state reflects whether any heavy operation (chat, summary, upload, vectorize) is
      in flight
- [ ] While busy, the controls that start a new heavy operation are disabled across pages
- [ ] When no heavy operation is running, all controls are enabled as normal
- [ ] Lightweight actions (e.g. saving or editing notes, navigation) are not blocked by the busy
      gate
- [ ] A test asserts that starting one heavy operation disables triggering another until it
      completes
- [ ] All Flutter tests pass and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
