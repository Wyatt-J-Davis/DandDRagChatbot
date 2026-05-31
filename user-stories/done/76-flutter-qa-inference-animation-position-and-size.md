# Issue 76: Flutter: Q&A inference animation position and size

**Type:** AFK

## What to build

Move the `star-magic.json` inference animation so it appears immediately below the latest user message while a response is loading, and increase its size from 240×240 to 360×360.

Currently the animation sits below the `Expanded(ListView)` in the page `Column`, so it always renders near the bottom of the window regardless of where the last message is — creating a disconnected feel when there are few messages.

Fix: remove the animation from its current position outside the `ListView` and render it instead as a trailing item inside the `ListView.builder`, shown only when `isLoading` is true. This makes the animation scroll with the message list and appear naturally below the last bubble. The existing `_scrollToBottom()` call already runs when loading begins, so the animation will be kept in view automatically.

See `PRD.md` ("Chat Inference Animation") for high-level implementation details.

## Acceptance criteria

- [ ] While a Q&A response is loading, the animation appears directly below the last user message bubble
- [ ] The animation is 360×360
- [ ] The animation scrolls with the message list (it is part of the list, not a fixed overlay)
- [ ] `_scrollToBottom()` keeps the animation in view when it first appears
- [ ] The animation disappears once the response arrives or an error occurs
- [ ] The input row position is unaffected by this change

## Blocked by

None — can start immediately
