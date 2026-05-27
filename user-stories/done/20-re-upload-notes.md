# Issue 20: Re-upload notes to refresh knowledge base

## What to build

Ensure the upload flow is not one-shot — the user can pick and upload a new file at any time to replace the knowledge base. The upload button remains available after a successful upload.

## Acceptance criteria

- [ ] After a successful upload, the upload button is re-enabled
- [ ] Uploading a new file triggers a fresh `DatabaseHandler.generate_database()` run, replacing the previous database
- [ ] The previously displayed filename/path is updated to reflect the new upload
- [ ] No stale state from the previous upload interferes with the new one

## Blocked by

- Issue 19: Progress bar for notes vectorization
