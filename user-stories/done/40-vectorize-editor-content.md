# Issue 40: Vectorize editor content button + progress

## What to build

Add a "Vectorize" button in the Note Editor sidebar that strips Quill delta markup from the editor content, sends it to `/notes/vectorize`, and shows a progress indicator while the SSE stream runs.

## Acceptance criteria

- [ ] "Vectorize" button is visible in the Note Editor sidebar
- [ ] Tapping it extracts plain text from the Quill delta, then POSTs to `/notes/vectorize`
- [ ] A progress indicator is shown while the SSE stream is active
- [ ] Success state is shown when the `done: true` event arrives
- [ ] Vectorize button is disabled while vectorization is in progress
- [ ] An error message is shown if the SSE stream emits an error event

## Blocked by

- Issue 34: `flutter_quill` editor widget
- Issue 39: `/notes/vectorize` SSE endpoint
