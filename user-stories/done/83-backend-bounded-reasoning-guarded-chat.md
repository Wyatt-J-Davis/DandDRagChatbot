# Issue 83: Backend: Bounded, reasoning-guarded chat output

**Type:** AFK

## What to build

The chat endpoint must invoke the model with a bounded output budget and with reasoning disabled,
mirroring the existing summary path. Today chat uses an unbounded output (`num_predict=-1`) with no
reasoning guard, so pointing chat at a thinking/reasoning model can produce an enormous reasoning
trace that never stops — a genuinely endless operation.

Cap chat `num_predict` to a generous value (target ~2048 — well above the 2–3 short paragraphs chat
normally produces) and disable reasoning for chat, exactly as the summary handler already does. This
prevents runaway generation at the source; the per-call timeout (Issue 82) becomes a last resort
rather than the primary control.

See `PRD.md` ("Bounded, reasoning-guarded chat output") for high-level design choices.

## Acceptance criteria

- [ ] Chat loads the model with a bounded `num_predict` (~2048 target) instead of unbounded
- [ ] Chat disables reasoning for the model, mirroring the summary path's behavior
- [ ] Normal chat answers (2–3 short paragraphs) are unaffected and complete normally
- [ ] A test with the LLM mocked asserts chat loads the model with the bounded `num_predict` and
      reasoning disabled
- [ ] All tests pass (`run_tests.bat`) and the app smoke-tests without runtime exceptions

## Blocked by

None — can start immediately
