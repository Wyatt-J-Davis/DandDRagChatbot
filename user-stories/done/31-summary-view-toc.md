# Issue 31: Saved summary view with table of contents

## What to build

On the Summary page, fetch and display the saved summary from GET `/summary`, rendered with a table of contents that lets the user navigate long summaries by section.

## Acceptance criteria

- [ ] Summary page fetches GET `/summary` on load
- [ ] Summary body is displayed with section headings
- [ ] A table of contents lists the section headings and scrolls the view to the selected section on tap
- [ ] If no summary exists yet, the page shows a prompt to generate one
- [ ] Summary content is scrollable

## Blocked by

- Issue 30: `/summary` GET endpoint
