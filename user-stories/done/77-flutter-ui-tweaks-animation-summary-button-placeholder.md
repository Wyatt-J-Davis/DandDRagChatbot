# Issue 77: Flutter: UI tweaks — animation size, summary button, Q&A placeholder

**Type:** AFK

## What to build

Three small, independent UI corrections on the Q&A and Campaign Summary pages:

1. **Larger loading animation.** Enlarge the `star-magic.json` loading Lottie to 720×720 on **both** the Q&A page (currently 360×360) and the Campaign Summary page (currently 240×240), so the two pages match and the animation is clearly visible. On the Q&A page the animation already renders inside the 720px-wide centered message column, so 720 fills that column; on the Summary page it is centered and unconstrained, so confirm it does not cause awkward vertical overflow.

2. **Single state-driven summary button.** On the Campaign Summary page, render a single generation button instead of two. Its label depends on whether a summary result currently exists: "Generate Summary" when there is no result, "Regenerate" once a result exists. Today "Generate Summary" is always shown and a second "Regenerate" button additionally appears once a result exists — so both show post-generation. There must never be a state where both labels appear. The button stays disabled while generation is in progress.

3. **Campaign-focused input placeholder.** Change the Q&A input field placeholder from "Ask a question…" to "Ask a question about the campaign…" (single ellipsis character `…`). Both the empty-state input and the active-chat input share one input-row builder, so the change applies to both.

See `PRD.md` (sections "Animation size", "Summary page button", and "Q&A input placeholder text") for high-level implementation details.

## Acceptance criteria

- [ ] The Q&A loading animation is 720×720 while a response is loading
- [ ] The Campaign Summary loading animation is 720×720 while a summary is generating
- [ ] When no summary result exists, exactly one button labelled "Generate Summary" is shown and "Regenerate" is absent
- [ ] When a summary result exists, exactly one button labelled "Regenerate" is shown and "Generate Summary" is absent
- [ ] The summary button is disabled while generation is in progress
- [ ] The Q&A input placeholder reads "Ask a question about the campaign…" in both the empty state and the active-chat state
- [ ] Widget tests cover the animation sizes, the state-driven button label, and the placeholder text
- [ ] All Flutter tests pass and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
