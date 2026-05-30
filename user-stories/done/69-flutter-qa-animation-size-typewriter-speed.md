# Issue 69: Flutter: Q&A inference animation 3× scale + typewriter 10× speed

**Type:** AFK

## What to build

Two related improvements to the Q&A chat experience:

**1. Larger inference animation.** The `star-magic.json` Lottie shown while the assistant is thinking is currently 80×80. Scale it to 240×240. Its position (centered, between the message list and the input row) is unchanged.

**2. Faster typewriter.** The `TypewriterController` currently reveals one character every 20 ms. Reduce the interval to 2 ms so the character-by-character streaming appears approximately 10× faster.

See `PRD.md` ("Flutter: Inference animation size" and "Flutter: Typewriter speed") for high-level intent.

## Acceptance criteria

- [ ] While the assistant is thinking, the Lottie animation renders at 240×240
- [ ] The animation remains centered between the message list and the input row
- [ ] Assistant responses stream in noticeably faster than before
- [ ] A short response (e.g. 50 characters) completes typewriter animation in under 200 ms
- [ ] `TypewriterController` unit test covers that the controller completes within an expected time bound for a fixed-length string at the 2 ms interval

## Blocked by

None — can start immediately
