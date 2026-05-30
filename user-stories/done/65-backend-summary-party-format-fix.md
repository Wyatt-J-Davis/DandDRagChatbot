# Issue 65: Backend: Summary crash fix for string party members

**Type:** AFK

## What to build

Fix a crash that occurs when generating a campaign summary after the second application launch. The error is `'str' object has no attribute 'get'` in `SummaryHandler._format_party_members`.

The root cause: on first launch party members are empty so the early-return path is taken. On subsequent launches, persisted party members are restored and the Flutter client sends them as a plain `list[str]`. The method assumes a `list[dict]` (each with a `name` key) and calls `.get()` on each element, crashing when it receives a string.

Make `_format_party_members` handle both formats: if an element is a dict, extract `name`; if it is already a string, use it directly. The fix should be robust to mixed lists.

See `PRD.md` ("Backend: Party member format handling in summary generation") for high-level intent.

## Acceptance criteria

- [ ] Generating a summary with party members set succeeds on the second app launch (no `'str' object has no attribute 'get'` error)
- [ ] `_format_party_members` returns the correct comma-separated string when given a `list[str]`
- [ ] `_format_party_members` returns the correct string when given a `list[dict]` with `name` keys (existing behaviour preserved)
- [ ] `_format_party_members` handles an empty list, returning a sensible fallback
- [ ] Covered by unit tests for each input format (strings, dicts, empty)

## Blocked by

None — can start immediately
