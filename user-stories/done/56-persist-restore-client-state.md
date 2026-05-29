# Issue 56: Persist + restore client and campaign state on launch

**Type:** AFK

## What to build

Make settings survive restarts. Persist pure-client preferences (note-editor dark-mode toggle and editor scroll offset; model and temperature are already persisted) in the client preferences file, and restore them on launch. Fetch party members from the backend `/party` endpoint on launch so party names persist across runs. The editor scroll offset is restored after the notes content has loaded.

See `PRD.md` ("Source of truth and persistence", "User preferences service", user stories 11, 13, 14, 31) for high-level decisions.

## Acceptance criteria

- [ ] Note-editor dark-mode toggle persists across restarts and is restored on launch
- [ ] Editor scroll offset persists across page switches and restarts, restored after notes content loads
- [ ] Party members are fetched from `/party` on launch so names persist across runs
- [ ] Model and temperature continue to persist and restore (no regression)
- [ ] Preference round-trip (dark mode, scroll offset) is covered by a unit test

## Blocked by

- None - can start immediately
