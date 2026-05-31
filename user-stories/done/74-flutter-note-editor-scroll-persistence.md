# Issue 74: Flutter: Note Editor scroll position persistence

**Type:** AFK

## What to build

Fix two independent scenarios where the Note Editor scroll position is lost:

**1. App restart race condition.** `_applyStoredPreferences()` (which loads the saved scroll offset from disk) and `_loadNotes()` (which uses that offset to restore scroll) are currently fired concurrently in `initState`. If `_loadNotes()` completes first, `_currentScrollOffset` is still zero and the scroll restore is silently skipped. Fix: extract a single `_initialize()` async method that awaits prefs load before calling `_loadNotes()`, guaranteeing the offset is set before the restore attempts to run.

**2. Tab-switch reset.** When the user navigates away from the Note Editor, the `QuillEditor` widget is removed from the tree and detaches from the `ScrollController`. On return the editor rebuilds at position zero. Fix: detect when `_selectedIndex` changes to the Note Editor tab and fire a `WidgetsBinding.instance.addPostFrameCallback` to restore the scroll to `_currentScrollOffset` after the editor widget has rebuilt.

See `PRD.md` ("Scroll Position Persistence") for high-level implementation details.

## Acceptance criteria

- [ ] After restarting the app, the Note Editor opens at the same scroll position it was at when last used
- [ ] Navigating to the Q&A or Summary tab and back does not reset the Note Editor scroll position
- [ ] Scroll position is not restored when it was never set (i.e. the editor opens at the top on a fresh install)
- [ ] The restore does not overshoot — the position is clamped to `maxScrollExtent` if the document has shrunk since last session

## Blocked by

None — can start immediately
