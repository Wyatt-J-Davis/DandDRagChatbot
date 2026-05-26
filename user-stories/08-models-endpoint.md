# Issue 8: `/models` endpoint

## What to build

Add a GET `/models` route to the FastAPI app that returns the list of available Ollama models by calling `LLMHandler.get_available_models()`.

## Acceptance criteria

- [ ] GET `/models` returns HTTP 200 with a JSON array of model name strings
- [ ] Returns an empty array (not an error) when Ollama has no models loaded
- [ ] `LLMHandler` is injected as a dependency so the route is testable in isolation
- [ ] Route is covered by a `TestClient` test with a mocked `LLMHandler`

## Blocked by

- Issue 1: FastAPI skeleton
