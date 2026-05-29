# Issue 2: `/health` endpoint

## What to build

Add a GET `/health` route to the FastAPI app that returns a JSON response indicating the server is up. This is the endpoint Flutter polls during startup to know when the backend is ready.

## Acceptance criteria

- [ ] GET `/health` returns HTTP 200 with body `{"status": "ok"}`
- [ ] Endpoint responds within 200ms under normal conditions
- [ ] Route is covered by a `TestClient` test

## Blocked by

- Issue 1: FastAPI skeleton
