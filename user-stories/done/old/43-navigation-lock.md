# Issue 43: Navigation lock during long-running SSE operations

## What to build

Disable the `NavigationRail` destinations while any SSE operation (upload, summary generation, notes vectorization) is in progress, preventing the user from accidentally navigating away and interrupting the operation.

## Acceptance criteria

- [ ] All `NavigationRail` destinations are disabled (visually grayed out and non-interactive) while any SSE stream is active
- [ ] Navigation is re-enabled immediately when the active SSE stream completes or errors
- [ ] The currently active page remains visible during the lock
- [ ] The lock applies to upload (Issue 19), summary generation (Issue 29), and notes vectorization (Issue 40)

## Blocked by

- Issue 19: Upload progress bar
- Issue 29: Summary progress messages
- Issue 40: Vectorize editor content
