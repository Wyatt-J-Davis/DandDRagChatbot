# Issue 60: Streaming response typewriter + thinking animation

**Type:** AFK

## What to build

Make chat responses feel alive. While the backend is working and before any answer text arrives, play the `star-magic.json` Lottie centered under the latest user query. When the answer arrives, remove the animation and reveal the answer character-by-character at 0.02 seconds per character (a client-side typewriter on the full answer — the backend delivers the answer whole, not token-streamed).

See `PRD.md` ("Chat", "Typewriter/streaming text", "Inference feedback", user stories 24–26) for high-level decisions.

## Acceptance criteria

- [ ] While the bot is thinking (before answer text), `star-magic.json` plays centered under the latest user query
- [ ] The thinking animation disappears when the answer begins streaming
- [ ] The answer reveals character-by-character at 0.02s per character
- [ ] Reference chips and the completed bubble render normally once typing finishes
- [ ] The typewriter controller (in-order reveal at the configured interval, terminates at the full string) is covered by a unit test

## Blocked by

- Issue 51: Bundle Lottie assets + add `lottie` dependency
- Issue 57: Long-running operation manager
- Issue 59: Q&A welcome state + thematic nav icons
