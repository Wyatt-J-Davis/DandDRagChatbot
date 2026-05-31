# Issue 75: Flutter: Vectorization animation layout fix

**Type:** AFK

## What to build

Fix the Settings popup so that during note vectorization the Lottie loading animation and the `LinearProgressIndicator` appear as two distinct, vertically-separated elements — animation above, progress bar below — rather than the animation being overlaid on top of the progress bar.

The fix is structural: replace the `Stack` wrapping both elements in the Notes Upload Button with a `Column(mainAxisSize: MainAxisSize.min)`, with 8 px spacing between the animation and the bar.

See `PRD.md` ("Vectorization Animation Layout") for high-level implementation details.

## Acceptance criteria

- [ ] During vectorization, the Lottie animation appears above the progress bar with no visual overlap
- [ ] The progress bar is fully readable while the animation plays
- [ ] The layout change does not affect the behavior or appearance of the upload button when not vectorizing
- [ ] The animation and progress bar are both visible at the same time during an active vectorization

## Blocked by

None — can start immediately
