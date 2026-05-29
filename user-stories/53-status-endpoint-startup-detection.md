# Issue 53: `/status` endpoint + startup notes detection

**Type:** AFK

## What to build

A backend `/status` endpoint that reports whether notes exist, keyed off the presence of the raw-notes file (the same artifact the summarizer requires, so status can't drift out of sync with summary availability). On launch the Flutter client calls `/status` and uses the result so the Q&A page offers "Re-upload notes" instead of "Upload" when notes already exist. This fixes the bug where a restart made the app act as if no notes were vectorized.

Response shape: `{ "has_notes": boolean }`.

See `PRD.md` ("`/status` endpoint", user stories 1–2) for high-level decisions.

## Acceptance criteria

- [ ] `GET /status` returns `{ "has_notes": boolean }` based on the raw-notes file's existence
- [ ] The Flutter client queries `/status` on launch and stores the `has_notes` flag in app state
- [ ] When `has_notes` is true, the Q&A page shows "Re-upload notes"; otherwise "Upload notes"
- [ ] The flag is correct across restarts (notes vectorized in a prior run are detected)
- [ ] `/status` is covered by a backend test (notes present vs absent)

## Blocked by

- Issue 52: Persist canonical notes on vectorize
