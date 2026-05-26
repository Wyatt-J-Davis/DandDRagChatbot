# Issue 33: Regenerate summary button

## What to build

Add a "Regenerate" button to the Summary page that re-triggers `/summary/generate`, shows the SSE progress messages, and replaces the displayed summary with the new one on completion.

## Acceptance criteria

- [ ] "Regenerate" button is visible on the Summary page when a summary exists
- [ ] Tapping it re-triggers the full generation flow (progress messages shown, Issue 29 flow)
- [ ] When the new generation completes, the displayed summary is refreshed by re-fetching GET `/summary`
- [ ] Regenerate button is disabled while generation is in progress

## Blocked by

- Issue 29: Summary progress messages
- Issue 31: Saved summary view with table of contents
