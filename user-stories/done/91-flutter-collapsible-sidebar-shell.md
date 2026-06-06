# Issue 91: Flutter: Collapsible sidebar shell

**Type:** AFK

## What to build

Replace the always-visible `NavigationRail` in `MainShell` with a unified, collapsible left sidebar (Ollama-style), and add a menu button that toggles it.

The expanded sidebar contains: a top hamburger (`☰`), the page navigation destinations (Q&A / Summary / Note Editor), and Settings at the bottom. A region is reserved for the chat history list, which is added in a later slice (empty placeholder for now).

The hamburger **fully hides** the sidebar; when collapsed, only a small floating hamburger button remains (top-left, overlaying the page) to reopen it. Page content gets padding so the floating button never covers existing top-left page controls on any of the three pages.

The collapsed/expanded state is persisted: add a `sidebarCollapsed` boolean to `UserPreferences`/`UserPreferencesService` (default expanded) so the app reopens in the state the user left it.

This slice is independent of the conversation persistence work and can be built in parallel.

See `PRD.md` ("Chat History & Collapsible Menu Sidebar") for high-level implementation details.

## Acceptance criteria

- [ ] The `NavigationRail` is replaced by a unified collapsible sidebar containing nav destinations and Settings
- [ ] Clicking the hamburger collapses the sidebar so it is fully hidden, leaving only a floating hamburger button
- [ ] Clicking the floating hamburger re-expands the sidebar
- [ ] Page navigation (Q&A / Summary / Note Editor) and Settings remain reachable from the expanded sidebar
- [ ] The floating hamburger does not overlap existing top-left controls on any page
- [ ] `sidebarCollapsed` persists to `user_data.json`; the app reopens in the last-used state (default expanded)
- [ ] Backend (`api/main.py`) is unchanged

## Blocked by

None — can start immediately
