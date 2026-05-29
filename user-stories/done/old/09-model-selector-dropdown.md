# Issue 9: Flutter model selector dropdown in sidebar panel

## What to build

Add a dropdown widget to the sidebar panel on the Q&A page that fetches the model list from GET `/models` and lets the user select which Ollama model to use. The selected model is stored in `AppStateNotifier`.

## Acceptance criteria

- [ ] Dropdown is populated from the `/models` response on page load
- [ ] Selected model is stored in `AppStateNotifier` and accessible to the chat flow
- [ ] Dropdown shows a loading indicator while `/models` is being fetched
- [ ] If the fetch fails or returns an empty list, the dropdown is disabled with a visible placeholder

## Blocked by

- Issue 7: Sidebar panel placeholder
- Issue 8: `/models` endpoint
