# Issue 44: Toast notifications on operation completion

## What to build

Show a brief toast notification (SnackBar) when a long-running operation completes successfully, so the user gets non-blocking feedback without the UI being interrupted.

## Acceptance criteria

- [ ] A toast is shown after successful notes upload (Issue 19)
- [ ] A toast is shown after successful summary generation (Issue 29)
- [ ] A toast is shown after successful notes vectorization (Issue 40)
- [ ] Toast messages are brief and descriptive (e.g. "Notes uploaded successfully")
- [ ] Toasts dismiss automatically after a few seconds
- [ ] No toast is shown on error — errors use their own inline message (covered per-feature)

## Blocked by

- Issue 19: Upload progress bar
- Issue 29: Summary progress messages
- Issue 40: Vectorize editor content
