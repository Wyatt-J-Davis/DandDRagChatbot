# Issue 22: `/chat` SSE endpoint

## What to build

Add a POST `/chat` endpoint that accepts a question and streams the LLM response along with the retrieved source chunks as SSE events, using `LLMHandler` and `DatabaseHandler.retrieve_notes()`.

## Acceptance criteria

- [ ] POST `/chat` accepts a JSON body with `question` (string), `model` (string), and `temperature` (float) fields
- [ ] Streams SSE events: progress events during retrieval, then a final `{"done": true, "answer": "<str>", "sources": [<chunk>, ...]}` event
- [ ] `LLMHandler` and `DatabaseHandler` are injected as dependencies
- [ ] Returns an SSE error event if the LLM or database raises
- [ ] SSE sequence covered by an `httpx.AsyncClient` test asserting correct event order

## Blocked by

- Issue 1: FastAPI skeleton
