# Issue 29: Summary generation progress messages (map / reduce / synthesis)

## What to build

Wire the Summary page "Generate" button to the `/summary/generate` endpoint and display the incoming SSE progress messages so the user knows which phase is running.

## Acceptance criteria

- [ ] Tapping "Generate Summary" sends a POST `/summary/generate` request with the current model and party members
- [ ] Each incoming SSE `message` value is displayed on the Summary page as the stream progresses
- [ ] Phase labels (map, reduce, synthesis) are shown distinctly
- [ ] When the `done: true` event arrives, the progress display is replaced by the summary view (Issue 31)
- [ ] Generate button is disabled while generation is in progress

## Blocked by

- Issue 28: `/summary/generate` SSE endpoint
