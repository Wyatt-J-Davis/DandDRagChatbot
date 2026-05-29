# Issue 23: Chat bubble UI: user + assistant variants

## What to build

Wire the chat input to the `/chat` endpoint and render responses as a `ListView` of `ChatBubble` widgets. User messages align to one side, assistant messages to the other.

## Acceptance criteria

- [ ] Submitting a question adds a user `ChatBubble` to the list immediately
- [ ] The SSE stream response populates an assistant `ChatBubble` when complete
- [ ] User and assistant bubbles are visually distinct (alignment, color, or shape)
- [ ] `ListView` scrolls to the latest message automatically after each response
- [ ] Selected model and temperature from `AppStateNotifier` are sent with each request

## Blocked by

- Issue 21: Chat input field
- Issue 22: `/chat` SSE endpoint
