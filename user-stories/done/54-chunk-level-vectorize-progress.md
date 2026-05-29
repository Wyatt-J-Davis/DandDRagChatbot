# Issue 54: Chunk-level vectorize progress

**Type:** AFK

## What to build

Fix the editor-vectorization progress bar that sits at 0 and then jumps to 100. Progress is currently reported per source journal entry; editor text without date headers parses to a single entry, so all the slow semantic chunking happens in one iteration with a single terminal yield. Change progress reporting to advance at chunk granularity so the user sees steady, advancing progress regardless of how many dated entries the input contains.

See `PRD.md` ("`generate_database` progress", user story 12) for high-level intent.

## Acceptance criteria

- [ ] Vectorizing single-entry text (no date headers) yields multiple advancing progress values, not a single 100% at the end
- [ ] Vectorizing multi-entry text still reports sensible monotonic progress
- [ ] Progress reaches 100% on completion and surfaces in the UI progress bar
- [ ] Covered by a test asserting multiple advancing progress values for single-entry input

## Blocked by

- None - can start immediately
