# PRD: Flutter UI Polish, Bug Fixes, and Chat Redesign

## Problem Statement

As a player using the TTRPG chatbot, the app has several rough edges that make it feel unfinished and frustrating to use across sessions. The progress bar during vectorization jumps instantly to 100% rather than advancing steadily, giving no feedback about how long the operation will actually take. The magical loading animation sits above the progress bar instead of overlaying it as intended. After restarting the app, my selected note taker is forgotten even though party members are restored. The settings panel incorrectly shows "No notes loaded" while vectorization is actively happening and even after it completes. The inference animation in Q&A is too small, text responses appear too slowly, and the chat window stretches across the full window width rather than feeling focused and compact like modern chat apps. Generating a campaign summary fails entirely on the second launch with a Python error because the backend mishandles the party members format sent from Flutter.

## Solution

Fix all nine identified issues across the Flutter UI and Python backend so the app behaves consistently, gives accurate feedback, and presents a polished, Ollama-inspired chat experience:

- The Python backend emits genuine incremental progress during embedding by batching `add_documents` calls inside the vectorization loop, and handles party member lists in either string or dict format so summary generation never crashes.
- The Flutter UI overlays the loading animation centered on the progress bar, restores the note taker selection on startup, hides status text during operations and shows "Notes processed" after any vectorization completes, and marks notes as available after vectorization from either path.
- The Q&A chat window is constrained to a centered 720px column with a rounded-border input container matching the Ollama aesthetic, the inference animation is tripled in size, typewriter speed is increased tenfold, and the campaign summary page gains the same Lottie animation during generation.

## User Stories

1. As a player, I want the vectorization progress bar to advance steadily as my notes are embedded, so that I can see the operation is working and estimate how long it will take.
2. As a player, I want the magical loading animation to appear centered on top of the progress bar during vectorization, so that the animation and progress feel visually unified.
3. As a player, I want my selected note taker to be restored when I reopen the app, so that I do not have to re-select it every session.
4. As a player, I want the notes status not to show "No notes loaded" while vectorization is actively running, so that I am not shown incorrect information about the state of my notes.
5. As a player, I want the notes status to show "Notes processed" after vectorization completes (whether from the note editor or the settings upload flow), so that I know my notes are ready to query.
6. As a player, I want vectorizing notes from the note editor to mark notes as available in the settings panel, so that the app reflects a consistent notes state regardless of which vectorization path I used.
7. As a player, I want the inference animation in the Q&A page to be noticeably larger, so that it is clearly visible while the assistant is thinking.
8. As a player, I want the assistant's response to stream in faster, so that the typewriter effect feels snappy rather than slow.
9. As a player, I want the campaign summary page to show the same themed loading animation while generating a summary, so that the experience is visually consistent with the Q&A page.
10. As a player, I want the chat window to be centered and constrained in width rather than spanning the full window, so that the conversation feels focused and easy to read.
11. As a player, I want the message input field to have a visible rounded border, so that the input area looks clean and intentional like a polished chat app.
12. As a player, I want the message list to also be constrained in width and centered, so that long assistant responses do not stretch edge-to-edge on wide screens.
13. As a player, I want generating a campaign summary to succeed when party members have been saved from a previous session, so that I do not see a Python error on the second launch.
14. As a player, I want generating a summary to succeed regardless of whether party members are sent as strings or as structured objects, so that the feature is robust to format differences between the frontend and backend.

## Implementation Decisions

### Backend: Incremental vectorization progress

The `DatabaseHandler.generate_database` method currently yields progress per document object constructed (a fast in-memory loop), then calls `vector_store.add_documents` once at the end — the actual slow embedding step. Progress will be made genuine by batching document objects and calling `add_documents` in small batches (e.g. 10 documents per batch) inside the loop, yielding progress after each batch so the reported percentage tracks real embedding work.

### Backend: Party member format handling in summary generation

`SummaryHandler._format_party_members` assumes each element is a dict with a `name` key, but the Flutter client sends party members as a plain list of strings. The fix makes the method handle both formats — if an element is a dict, extract `name`; if it is already a string, use it directly. This resolves the `'str' object has no attribute 'get'` crash that occurs on the second launch once party members have been persisted and restored.

### Flutter: Note taker persistence on startup

`PartyService.fetchPartyMembers` currently discards the `note_taker` boolean returned by the `/party` backend endpoint and returns only a list of names. It will be updated to also return the note taker name (the first member whose `note_taker` field is `true`). The startup loading logic in `MainShell` will call `setNoteTaker` with the restored value alongside the existing `setPartyMembers` call.

### Flutter: Notes status text logic

The "No notes loaded" / "Notes loaded" status text in `NotesUploadButton` will be updated:
- Hidden while any upload or vectorize operation is actively running.
- Shows "Notes processed" after any vectorization completes (either the upload flow or the note editor vectorize flow).
- `OperationManager` will call `appState.setHasNotes(true)` in the vectorize-done handler, mirroring what the upload-done handler already does.

### Flutter: Lottie animation overlay in settings

The loading animation and progress bar in `NotesUploadButton` will be rendered using a `Stack` widget so the Lottie animation (80×80) appears centered on top of the `LinearProgressIndicator` rather than above it in a column.

### Flutter: Inference animation size

The `Lottie.asset` widget in `QAPage` will be scaled from 80×80 to 240×240. Its position (below the message list, above the input row, centered) is unchanged.

### Flutter: Typewriter speed

`TypewriterController` will reduce its tick interval from 20 ms to 2 ms, making the character-by-character streaming appear approximately 10× faster.

### Flutter: Summary page animation

`SummaryPage` will add a `Lottie.asset` using the same `star-magic.json` animation at 240×240, shown during summary generation alongside the existing `LinearProgressIndicator` (the progress bar is retained).

### Flutter: Chat window layout

`QAPage` will wrap both the message `ListView` and the input row in a centered `ConstrainedBox` with `maxWidth: 720`, consistent with the already-constrained empty-state layout. The input `TextField` will be wrapped in a `Container` with a `BoxDecoration` using a rounded border and a subtle background fill to match the Ollama input bubble aesthetic. Existing chat bubble styling (user right-aligned with primary color, assistant left-aligned with surfaceVariant) is retained.

## Testing Decisions

Good tests verify observable behavior through the module's public interface without coupling to internal implementation details such as widget tree structure or private method calls.

### Modules to test

- **`SummaryHandler._format_party_members`** (Python): Test that it returns the correct formatted string when given a list of strings, a list of dicts, a mixed list, and an empty list. Prior art: `tests/test_summary_handler.py`.
- **`DatabaseHandler.generate_database`** (Python): Test that the generator yields at least two distinct progress values less than 100 before the done event, confirming incremental progress is emitted. Prior art: `tests/test_database_handler.py`.
- **`PartyService`** (Flutter): Test that `fetchPartyMembers` returns both the member list and the note taker name when the backend response includes `note_taker: true` on one member. Prior art: `ui/test/services/party_service_test.dart`.
- **`TypewriterController`** (Flutter): Test that the controller completes in under a threshold time for a fixed-length string at the new interval. Prior art: `ui/test/state/typewriter_controller_test.dart`.
- **`OperationManager`** (Flutter): Test that completing a vectorize operation (not just an upload) causes `appState.hasNotes` to become `true`. Prior art: `ui/test/state/operation_manager_test.dart`.

### What makes a good test here

Tests should drive the module through its public API (call the method, stream the generator, listen to the notifier) and assert on the outcome (return value, emitted events, state changes). They should not assert on which internal helpers were called or in what order.

## Out of Scope

- Changing the visual design of chat message bubbles (user vs. assistant bubble colors and shapes are unchanged).
- Adding Ollama-style extras to the input area (model selector dropdown, web search button, etc.).
- Any changes to the note editor UI beyond what is already implemented.
- Streaming chat responses token-by-token from the backend (the backend still returns the full answer at once; only the typewriter display speed changes).
- Introducing new backend endpoints or changing existing API contracts beyond the party member format fix.

## Further Notes

The summary error only manifests on the second app launch because on the first launch party members are empty, causing `_format_party_members` to take the early-return path that never calls `.get()`. Any manual test of summary generation should include: launch app, add party members, restart app, then generate summary — this is the only sequence that triggers the crash.

The vectorization progress fix requires that `add_documents` accepts incremental calls without duplicating data. Chroma's `add_documents` is additive by document ID, so batching is safe as long as IDs remain unique across the full run (the existing sequential integer ID scheme already guarantees this).
