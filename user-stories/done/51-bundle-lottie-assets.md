# Issue 51: Bundle Lottie assets + add `lottie` dependency

**Type:** AFK

## What to build

Foundational asset setup for the themed animations used elsewhere. Copy `Magical_Effect_Loading.json` and `star-magic.json` from the project `assets/` directory into the Flutter project's asset location, declare them in the package manifest, and add a Lottie rendering dependency so later slices can play them.

See `PRD.md` ("Assets and packaging") for the high-level intent.

## Acceptance criteria

- [ ] `Magical_Effect_Loading.json` and `star-magic.json` are bundled with the Flutter app and load at runtime
- [ ] A Lottie dependency is added to the package manifest and resolves
- [ ] A minimal render check confirms at least one animation plays without errors
- [ ] `icon.ico` remains available for the packaging slice (no regression to existing assets)

## Blocked by

- None - can start immediately
