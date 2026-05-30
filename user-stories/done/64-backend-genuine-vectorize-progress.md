# Issue 64: Backend: Genuine incremental vectorization progress

**Type:** AFK

## What to build

Fix the vectorization progress bar so it advances steadily as notes are embedded rather than jumping instantly to 100%. The root cause is that `DatabaseHandler.generate_database` currently yields progress per document object *constructed* (a fast in-memory loop), then calls `vector_store.add_documents` once for all documents at the end — the actual slow embedding step produces no progress events.

Batch documents and call `add_documents` in small batches (e.g. 10 documents per batch) inside the loop, yielding a progress percentage after each batch. Because Chroma's `add_documents` is additive by document ID, batching is safe as long as IDs remain unique across the full run (the existing sequential integer ID scheme already guarantees this).

See `PRD.md` ("Backend: Incremental vectorization progress") for high-level intent.

## Acceptance criteria

- [ ] Vectorizing a non-trivial set of notes yields multiple distinct progress values between 0 and 100 before the done event
- [ ] Progress values are monotonically increasing
- [ ] The final event reports 100% and the vector store contains all documents
- [ ] Vectorizing a very small note set (fewer chunks than the batch size) still completes successfully
- [ ] Covered by a test asserting that at least two distinct sub-100 progress values are yielded before completion

## Blocked by

None — can start immediately
