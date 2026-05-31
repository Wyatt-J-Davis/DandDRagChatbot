# Issue 73: Flutter + Backend: Summary temperature threading & model load fix

**Type:** AFK

## What to build

Fix the campaign summary feature, which currently always errors with "No model loaded. Please load a model before invoking" regardless of the model selected in Settings.

Root cause: `SummaryHandler.generate_summary_streaming()` calls `invoke_model()` directly without first calling `load_model()`, so the LLM handler is always in its uninitialized state when summary generation begins.

Fix: call `load_model()` at the top of `generate_summary_streaming()` before any model invocation. Thread the temperature setting from the Settings menu all the way through to the backend so that summary generation uses the same temperature the user configured — consistent with how the Q&A chat flow works.

The change touches five layers end-to-end:

- `SummaryPage` reads `appState.temperature` and passes it to `startSummary()`
- `OperationManager.startSummary()` accepts and forwards `temperature`
- `SummaryService.generate()` includes `temperature` in the POST body
- The backend `SummaryGenerateRequest` gains an optional `temperature` field (default `0.7`)
- `SummaryHandler.generate_summary_streaming()` accepts `temperature`, calls `load_model()` with it and `disable_thinking=True` before generating

See `PRD.md` ("Summary Temperature Threading") for high-level implementation details.

## Acceptance criteria

- [ ] Clicking "Generate Summary" with a model selected in Settings no longer produces a "No model loaded" error
- [ ] Summary generation completes successfully end-to-end
- [ ] The temperature used for summary generation matches the value set in the Settings menu
- [ ] Changing the temperature slider and regenerating uses the updated value
- [ ] The backend `SummaryGenerateRequest` defaults to `0.7` if no temperature is supplied (backwards compatible)

## Blocked by

None — can start immediately
