# Issue 79: Flutter: Loading animation actually renders larger (fit + size)

**Type:** AFK

## What to build

The loading sparkle on the Q&A page and the Campaign Summary page must visibly render larger — about three times its current on-screen surface area — and sit just below the last message, horizontally centered in the chat column, instead of floating in the vertical middle of the window.

A previous change bumped the loading Lottie's size (Q&A 360→720, Summary 240→720) but produced **no visible change**, because the `lottie` package (v3.3.3) defaults a `Lottie.asset` widget's `fit` to `BoxFit.scaleDown`, which only ever shrinks the source. The `star-magic.json` asset has a 40×40 composition canvas, so with `scaleDown` it renders at its native ~40px regardless of the widget's `width`/`height`, centered inside the oversized box. The "floating in the middle" symptom is a side effect of that oversized box: the Q&A loading indicator is a list item sized 720 tall, so the ~40px sparkle is centered roughly 360px below the last message.

**Fix:** On both pages, change the loading Lottie's `width`/`height` from `720` to `70` and add an explicit `fit: BoxFit.contain`. `70` yields roughly three times the current rendered area (√3 × ~40 ≈ 70 logical px per side). Because both the box and the asset canvas are square, `contain`/`cover`/`fill` are equivalent here; `contain` is the conventional choice. No layout, `Center`, or list-structure changes are needed — the existing `Center` wrappers already produce the desired container behavior once the box shrinks:

- **Q&A:** the loading item is a `Center` inside the message `ListView`. In a vertical list the cross axis (width) is bounded to the 720 column so the container spans the full chat-window width, while the main axis (height) is unbounded so the container shrinks to exactly the animation's height (no extra vertical space). The animation is horizontally centered and sits immediately below the last message.
- **Summary:** the `Center`-wrapped animation sits in the page column immediately above the `LinearProgressIndicator`, so it is horizontally centered in the page and directly above the loading bar.

Leave the chat column width (`maxWidth: 720`) unchanged. Leave the Summary page button, progress indicator, and Q&A input placeholder unchanged.

See `PRD_animation_size_fit_fix.md` for full details.

## Acceptance criteria

- [ ] The Q&A loading Lottie renders at `width: 70`, `height: 70` with `fit: BoxFit.contain` while the bot is thinking
- [ ] The Summary loading Lottie renders at `width: 70`, `height: 70` with `fit: BoxFit.contain` while generating
- [ ] On the Q&A page, the animation's container spans the full chat-column width and is exactly the animation's height (no extra vertical space), positioned immediately below the last message, with the animation horizontally centered
- [ ] On the Summary page, the animation is horizontally centered in the page and sits directly above the loading bar
- [ ] The chat column `maxWidth: 720` constraints are unchanged
- [ ] The Q&A size test asserts `width == 70`, `height == 70`, and `fit == BoxFit.contain` (the `fit` assertion guards against a silent revert to `scaleDown`)
- [ ] The Summary size test asserts `width == 70`, `height == 70`, and `fit == BoxFit.contain`
- [ ] The `_setLargeView` helpers in the Summary page tests are left in place
- [ ] All Flutter tests pass and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
