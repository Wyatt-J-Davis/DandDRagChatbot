# Issue 81: Backend: Shared singleton handlers built once at startup

**Type:** AFK

## What to build

The database handler and LLM handler must be constructed once at application startup and reused
across all requests, instead of being rebuilt per request via dependency injection.

Today each request gets a fresh `DatabaseHandler`, so the initialization guard in
`create_retrival_artifacts` (`if self.vector_store is not None: return`) never fires — every single
chat reloads the FastEmbed/ONNX embedding model and reopens the Chroma/SQLite store from scratch.
That is both a major per-request cost and exactly the kind of repeated native-resource init that
deadlocks under overlap. Reusing one instance eliminates that reload.

This is sequenced after the global lock (Issue 80) because the lock is what makes shared mutable
handler state safe to access across requests.

See `PRD.md` ("Shared singleton handlers") for high-level design choices.

## Acceptance criteria

- [ ] `DatabaseHandler` and `LLMHandler` are each instantiated once at startup and reused across
      requests
- [ ] Repeated chat requests do NOT reload the embedding model or reopen the vector store (the
      retrieval artifacts are built once and reused)
- [ ] Operations that intentionally rebuild the store (upload-notes, vectorize) still correctly
      clear and regenerate it on the shared instance
- [ ] Behavior is unchanged from the user's perspective aside from responsiveness (answers,
      summaries, vectorize results remain correct)
- [ ] All tests pass (`run_tests.bat`) and the app smoke-tests without runtime exceptions

## Blocked by

- Issue 80 (Backend: Serialize heavy operations behind a global lock with busy-rejection)
