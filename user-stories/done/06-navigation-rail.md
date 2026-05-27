# Issue 6: Flutter shell: `NavigationRail` with 3 destinations + empty page stubs

## What to build

Add a persistent `NavigationRail` on the left side of the main shell with three destinations: Q&A, Summary, and Note Editor. Each destination navigates to a blank stub widget. No content in the pages yet.

## Acceptance criteria

- [ ] `NavigationRail` is visible on all pages with Q&A, Summary, and Note Editor destinations
- [ ] Each destination has an icon and a label
- [ ] Tapping a destination swaps the main content area to the corresponding stub page
- [ ] Selected destination is visually highlighted
- [ ] Rail is always visible (not hidden on any page)

## Blocked by

- Issue 5: Loading screen
