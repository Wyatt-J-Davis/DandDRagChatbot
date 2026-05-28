# Issue 32: Summary metadata display (model used, generation date)

## What to build

Display the metadata from the saved summary (which model generated it and when) in the Summary page view so the user knows how fresh the summary is.

## Acceptance criteria

- [ ] Model name and generation date are displayed visibly on the Summary page (e.g. in a subtitle row beneath the title)
- [ ] Metadata is sourced from the `campaign_summary.json` fields returned by GET `/summary`
- [ ] If metadata fields are missing, the display degrades gracefully (no crash)

## Blocked by

- Issue 31: Saved summary view with table of contents
