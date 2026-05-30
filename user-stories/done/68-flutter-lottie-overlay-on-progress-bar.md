# Issue 68: Flutter: Lottie animation overlay centered on vectorization progress bar

**Type:** AFK

## What to build

In the settings popup upload area, change the layout so the magical loading animation appears centered on top of the `LinearProgressIndicator` during vectorization, rather than sitting above it as a separate element.

Currently the Lottie widget and the progress bar are siblings in a `Column`. Replace this with a `Stack` so the Lottie (80×80) is rendered centered over the bar. The bar should remain fully visible beneath the animation.

See `PRD.md` ("Flutter: Lottie animation overlay in settings") for high-level intent.

## Acceptance criteria

- [ ] During vectorization in the settings popup, the Lottie animation is visually centered on the progress bar (not above it)
- [ ] The progress bar remains visible and advances beneath the animation
- [ ] When vectorization is not running, neither the Lottie nor the progress bar is shown
- [ ] No layout overflow or clipping occurs at the default settings popup width

## Blocked by

None — can start immediately
