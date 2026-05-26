# Issue 27: Disable chat input while LLM is processing

## What to build

Disable the chat input field and submit button while an active SSE stream is in progress, preventing the user from submitting another question before the current one finishes.

## Acceptance criteria

- [ ] Input field and submit button are disabled from the moment a request is sent until the `done: true` event arrives
- [ ] A visual indicator (e.g. loading spinner near the input) signals that a response is being generated
- [ ] After the response completes, the input field is re-enabled and focused
- [ ] If the stream errors, the input is re-enabled and an error message is shown

## Blocked by

- Issue 23: Chat bubble UI
