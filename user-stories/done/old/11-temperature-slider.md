# Issue 11: Temperature slider in sidebar panel

## What to build

Add a temperature slider widget to the sidebar panel. The slider controls the LLM temperature value and stores it in `AppStateNotifier` for use by the chat flow.

## Acceptance criteria

- [x] Slider is visible in the Q&A sidebar panel
- [x] Range is 0.0 to 1.0 with a visible numeric readout of the current value
- [x] Selected temperature is stored in `AppStateNotifier`
- [x] Slider renders correctly within the fixed-width sidebar layout

## Blocked by

- Issue 7: Sidebar panel placeholder (complete)
