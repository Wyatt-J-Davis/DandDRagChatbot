# Issue 30: `/summary` GET endpoint

## What to build

Add a GET `/summary` endpoint that reads and returns the saved `campaign_summary.json`, including the summary body and metadata.

## Acceptance criteria

- [x] GET `/summary` returns HTTP 200 with the summary content and metadata (model used, generation date) from `campaign_summary.json`
- [x] Returns a 404 or empty response (not an error) if no summary has been generated yet
- [x] Route is covered by a `TestClient` test

## Blocked by

- Issue 1: FastAPI skeleton
