# Issue 58: Settings pop-up redesign

**Type:** HITL

## What to build

Replace the space-hogging Q&A settings sidebar with a compact pop-up. A settings icon in the lower-left of the navigation rail opens a pop-up menu, available on all three pages. The right sidebar is removed entirely, giving the chat window more room. The pop-up contains all options as labeled sections, top to bottom: Model, Temperature (with numeric value), Party Members (add field + deletable list), Note Taker (clearly labeled with a one-line helper "Whose perspective the AI answers from", presented as the existing single-select radio merged into the member list), and Notes (Re-upload/Upload button + "Notes loaded / none" indicator + vectorize progress area that plays the `Magical_Effect_Loading.json` Lottie during vectorization).

See `PRD.md` ("Settings pop-up", user stories 2, 18, 19, 20, 29, 30) for high-level decisions.

## Acceptance criteria

- [ ] A lower-left nav-rail settings icon opens a pop-up settings menu on all three pages
- [ ] The right sidebar is removed; the chat window gains the reclaimed space
- [ ] Pop-up has labeled sections: Model, Temperature (numeric value shown), Party Members, Note Taker, Notes
- [ ] Note Taker section is labeled with helper text and uses the existing single-select radio mechanism
- [ ] Notes section shows Re-upload/Upload per `has_notes` and a "Notes loaded / none" indicator
- [ ] `Magical_Effect_Loading.json` plays above the progress bar while notes vectorize
- [ ] Party member add/remove and note-taker selection continue to work and persist

## Blocked by

- Issue 51: Bundle Lottie assets + add `lottie` dependency
- Issue 53: `/status` endpoint + startup notes detection
- Issue 57: Long-running operation manager
