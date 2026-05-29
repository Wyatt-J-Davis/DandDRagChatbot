# Issue 19: Progress bar for notes vectorization

## What to build

Wire the file picker selection to the `/upload-notes` endpoint and render a progress bar in the Q&A sidebar that reflects the SSE stream progress while the notes are being vectorized.

## Acceptance criteria

- [x] After a file is selected, an "Upload" or "Vectorize" button triggers the POST `/upload-notes` request
- [x] A progress bar appears and updates as SSE `progress` values arrive
- [x] Progress bar reaches 100% and then hides (or shows a success state) when the `done: true` event arrives
- [x] An error message is shown if the SSE stream emits an error event
- [x] Upload button is disabled while upload is in progress

## Blocked by

- Issue 17: Native file picker
- Issue 18: `/upload-notes` SSE endpoint
