# Issue 70: Flutter: Campaign summary Lottie animation during generation

**Type:** AFK

## What to build

Add the `star-magic.json` Lottie animation to the campaign summary page so generation has the same themed visual feedback as the Q&A page. The animation should appear at 240×240, centered, while summary generation is running. The existing `LinearProgressIndicator` and progress message text are retained alongside the animation.

See `PRD.md` ("Flutter: Summary page animation") for high-level intent.

## Acceptance criteria

- [ ] While a summary is generating, the `star-magic.json` animation plays at 240×240 on the summary page
- [ ] The animation is centered horizontally
- [ ] The existing progress bar and progress message text remain visible during generation
- [ ] The animation disappears once generation completes or errors
- [ ] The animation does not appear when the page is idle or showing an existing summary

## Blocked by

None — can start immediately
