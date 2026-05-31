# PRD: Bug Fixes and Improvements to the Flutter TTRPG Chatbot

## Problem Statement

As a player using the desktop TTRPG chatbot, the app forgets things it shouldn't and behaves inconsistently between runs. After I vectorize my campaign notes and restart the app, the app acts as if no notes exist — it offers "Upload" instead of "Re-upload", the notes are gone from the editor, and generating a summary fails with "Raw notes not found" even though Q&A still answers with references. My typed notes, party members, dark-mode choice, and editor scroll position all reset on restart. Switching pages kills in-progress inference or vectorization and wipes my chat history. Vectorizing edited notes shows a progress bar that never moves. Source buttons are labeled "source1", "source2" instead of anything meaningful. On top of that, the layout wastes space: a large settings bar crowds the chat window, options are unlabeled, responses paste in all at once, and the interface lacks the polish of mainstream chatbots.

## Solution

Make the app's state durable and consistent across runs, keep long-running work alive across page switches, fix the backend so the summary and editor-vectorization features actually work, and redesign the Q&A layout around a compact pop-up settings menu so the chat has room to breathe. Concretely:

- The backend becomes the single source of truth for campaign data (party members, notes content, raw notes, vector DB, summary). It always persists raw notes whenever notes are vectorized, exposes a status check so the UI knows notes exist, and returns each source's date so chips are meaningful.
- The Flutter client keeps long-running SSE operations (chat, upload, vectorize, summary) alive independent of the visible page, persists pure-client preferences (model, temperature, dark mode, editor scroll position), and fetches campaign data from the backend on launch.
- The Q&A layout is rebuilt: a bottom-left settings icon opens a labeled pop-up with all options; the chat opens on a centered "welcome" state with a wizard, streams responses character-by-character, and plays themed Lottie animations during work.
- The note editor reflects whatever notes were last vectorized (from any source), reloads them on launch, drops the now-irrelevant Import button, moves vectorize controls to the top, and can export to txt/docx.

## User Stories

1. As a player, I want the app to recognize my previously vectorized notes after I restart it, so that I see "Re-upload" instead of "Upload" and know my notes are still loaded.
2. As a player, I want the settings to show that notes are loaded after a restart, so that I have a clear, persistent indicator of campaign-data state.
3. As a player, I want to generate a campaign summary successfully whenever my notes are vectorized, so that I never see "Raw notes not found" when notes clearly exist.
4. As a player, I want my typed and imported notes to reload when I reopen the app, so that I don't lose my work between sessions.
5. As a player, I want notes I vectorize from a file upload to appear in the note editor, so that I have one consistent notes body across the app.
6. As a player, I want the Import button removed from the note editor, so that the interface isn't cluttered with an option that's no longer relevant.
7. As a player, I want vectorized notes to overwrite the editor content, so that the editor always reflects the latest vectorized notes.
8. As a player, I want in-progress inference to keep running when I switch pages, so that I don't have to wait for it to restart when I return.
9. As a player, I want in-progress vectorization to keep running when I switch pages, so that long operations aren't lost on navigation.
10. As a player, I want my chat history to remain when I switch between pages, so that I don't lose the conversation context within a session.
11. As a player, I want the editor scroll position preserved across page switches and restarts, so that I return to exactly where I left off.
12. As a player, I want vectorizing edited notes to show real, advancing progress, so that I can tell the operation is working and roughly how long it will take.
13. As a player, I want my party member names to persist across restarts, so that I don't re-enter them every session.
14. As a player, I want the dark-mode toggle in the note editor to persist across restarts, so that the editor opens in my preferred theme.
15. As a player, I want chatbot source buttons labeled with the date of the referenced journal entry, so that I can tell which session a reference came from instead of "source1/source2".
16. As a player, I want to export my notes to a .txt or .docx file, so that I can use them outside the app.
17. As a player, I want any vectorized notes to automatically appear in the editor (even overwriting existing content), so that I never need a manual import step.
18. As a player, I want a magical Lottie animation to play above the loading bar while notes vectorize, so that the wait feels themed and intentional.
19. As a player, I want a compact settings icon in the lower-left that opens a pop-up settings menu, so that the chat window has more room.
20. As a player, I want the settings pop-up available on all three pages, so that I can adjust options without navigating back to Q&A.
21. As a player, I want distinctive page icons (magic orb for Q&A, AI sparkle for Summary, quill for Notes), so that the navigation is more thematic and legible.
22. As a player, I want the chat to open with the input centered and a large wizard above it, so that the empty state feels like a polished mainstream chatbot.
23. As a player, I want the chat to switch to the standard bottom-docked layout once I send my first message, so that the conversation view is familiar and usable.
24. As a player, I want chatbot responses to stream in character-by-character, so that replies feel alive rather than pasted all at once.
25. As a player, I want a star-magic Lottie animation under my latest query while the bot is thinking, so that I have clear, themed feedback that work is happening.
26. As a player, I want that thinking animation to disappear when the response starts streaming, so that the transition from "thinking" to "answering" is obvious.
27. As a player, I want the vectorize controls moved to the top of the note editor next to the dark-mode toggle, so that they're less intrusive in the writing area.
28. As a player, I want the executable to show the wizard icon in the taskbar, so that the app is recognizable among my open windows.
29. As a player, I want a clearly labeled "Note Taker" control with a short explanation, so that I understand it sets whose perspective the AI answers from.
30. As a player, I want every settings option labeled (Model, Temperature, Party Members, Note Taker, Notes), so that I know what each control does.
31. As a player, I want model and temperature selections remembered across restarts, so that I don't reconfigure inference each session.
32. As a player, I want export to reflect my current editor content, so that I don't export stale text.

## Implementation Decisions

### Source of truth and persistence
- The **backend is the source of truth for campaign data**: party members, notes content, raw notes, the vector database, and the summary. The Flutter client fetches these on launch.
- The **Flutter client persists only pure-client preferences**: selected model, temperature, note-editor dark-mode toggle, and editor scroll offset. These live in the client preferences file.
- Model and temperature are persisted client-side and continue to be sent in each `/chat` and `/summary/generate` request body; the backend remains stateless about UI selections.
- There is **one canonical notes body**. Vectorizing from any source (file upload on the Q&A page, or edit-and-vectorize in the editor) persists the same notes text. On launch the editor loads this text. Uploading a file overwrites the editor body.

### Backend modules (Python / FastAPI)
- **Notes persistence (deep module).** Extract the canonical notes/raw-notes persistence behind a single interface that: writes the raw-notes structure (the parsed DataFrame consumed by the summarizer) and the editor notes text together whenever notes are vectorized; reads the editor notes text; and reports whether notes exist. This consolidates file I/O currently scattered across the old Streamlit path and the API handlers, and removes the bug where vectorizing never wrote the raw-notes file.
- **`/upload-notes` and `/notes/vectorize` handlers.** After a successful vectorization, both persist the raw-notes structure and the editor notes text via the notes-persistence module. This fixes the summary "Raw notes not found" error and unifies the notes body.
- **`generate_database` progress.** Change progress reporting so it advances at chunk granularity rather than per source DataFrame row. Editor text typically parses to a single dated entry, which previously produced a single 100% yield only after all semantic chunking completed (the "no progress" bug).
- **`/chat` source payload.** Return each source as a structured object including the chunk's `Date` metadata (already attached during chunking) alongside its content, so the client can label reference chips by date.
- **`/status` endpoint (new).** Returns whether notes exist, keyed off the presence of the raw-notes file (the same artifact the summarizer requires, so the status can't drift out of sync with summary availability). Response shape: `{ "has_notes": boolean }`.

### Flutter modules
- **Long-running operation manager (deep module).** Own the SSE stream subscriptions for chat, upload, vectorize, and summary at app/notifier scope rather than in page widgets, so an operation's HTTP connection and progress survive page navigation and the result lands when complete. Exposes operation status/progress and the latest result; pages render from it.
- **`AppStateNotifier`.** Holds session chat history, party members, model, temperature, dark mode, editor scroll offset, and the `has_notes` flag; delegates long-running work to the operation manager.
- **User preferences service.** Extend the existing client preferences persistence to include dark-mode toggle and editor scroll offset (model and temperature already persisted).
- **Client data services.** Fetch `/status`, `/party`, and `/notes` on launch; `POST /party` and `POST /notes` on change; download `/notes/export/{txt,docx}`.
- **Typewriter/streaming text (deep module).** A small controller that reveals a completed answer string character-by-character at 0.02s per character; pure logic, decoupled from widgets.
- **Settings pop-up.** A pop-up launched from a bottom-left nav-rail icon, available on all pages. The right sidebar is removed entirely. Sections, all labeled top-to-bottom: Model, Temperature (with numeric value), Party Members (add field + deletable list), Note Taker (labeled with helper text "Whose perspective the AI answers from", presented as the existing single-select radio merged into the member list), Notes (Re-upload/Upload button + "Notes loaded / none" indicator + vectorize progress area with the `Magical_Effect_Loading.json` Lottie).
- **Q&A welcome state.** When the message list is empty, show a centered input with a large wizard emoji above it. As soon as there is at least one message, switch to the standard bottom-docked chat layout. Chat is session-only (cleared on restart), so every launch starts on the welcome state.
- **Inference feedback.** While the backend is working and before any answer text arrives, play `star-magic.json` centered under the latest user query; remove it when the answer begins typing in.
- **Reference chips.** Label each chip with the source's date, falling back to "Source N" when the date is unknown.
- **Note editor.** Remove the Import button; move vectorize controls to the top of the page beside the dark-mode toggle; add txt/docx export controls there as well. Save current editor content (`POST /notes`) before exporting so the export reflects current text. Use a native Save-As dialog for export destinations.
- **Navigation icons.** Material icons: an orb-style icon for Q&A, `Icons.auto_awesome` for Summary, a quill-style icon for Notes. The wizard on the welcome state is a Unicode emoji.

### Assets and packaging
- Copy `Magical_Effect_Loading.json` and `star-magic.json` into the Flutter project's assets, declare them in the package manifest, and add a Lottie dependency.
- Set the Windows runner application icon from `assets/icon.ico` so the wizard icon appears in the taskbar.

## Testing Decisions

Good tests verify **external, observable behavior through a module's public interface**, not its internal implementation. They should remain valid if the internals are refactored. The project already follows tests-first with pytest for the backend and `flutter_test` unit tests for client state and services; new tests follow that prior art.

Modules to test:
- **Backend notes-persistence module.** Given a vectorization, the raw-notes artifact and editor notes text are both written; `has_notes`/`/status` reports correctly before and after; reading returns the persisted content. This directly covers the summary "Raw notes not found" regression. Prior art: `tests/test_summary_handler.py`, `tests/test_database_handler.py`.
- **`/chat` source payload.** Sources returned include the date metadata; unknown dates are handled. Prior art: existing API/handler tests.
- **`generate_database` progress.** Vectorizing single-entry (no date headers) text yields multiple advancing progress values rather than a single terminal value. Prior art: `tests/test_database_handler.py`.
- **Flutter typewriter controller.** Reveals the full string in order at the configured interval and terminates at the complete string — pure logic, easily unit-tested. Prior art: existing `AppStateNotifier`/service unit tests.
- **Flutter operation manager.** State transitions (idle → running → done/error) and that progress/result are retained independent of any page, so a "page switch" (no teardown of the manager) preserves in-flight state. Prior art: `test/` BackendService and AppStateNotifier unit tests with a mock HTTP server.
- **User preferences round-trip.** Dark mode and scroll offset persist and reload alongside model/temperature. Prior art: AppStateNotifier persistence unit tests.

Confirm with the developer which of these modules should have tests written first; the deep modules (notes-persistence, typewriter controller, operation manager) are the highest-value candidates.

## Out of Scope

- Persisting chat transcripts across app restarts, and any "saved conversations" / "new chat" history-management UI. Chat history persists across page switches only.
- Token-level streaming from the LLM. Responses are delivered whole by the backend and revealed client-side with a fixed-interval typewriter effect.
- Backend persistence of UI selections (model/temperature); these remain client-side and ride along per request.
- Displaying the original uploaded filename in settings; the notes indicator is a simple loaded/empty state.
- Animated transition between the centered welcome state and the docked chat layout; the switch is a conditional show/hide on chat emptiness.
- Custom artwork/SVGs for navigation icons; built-in Material icons are used (a single image asset may be substituted later for the orb or quill if a built-in proves unsatisfactory).
- Rich-text fidelity (formatting) round-tripping through notes persistence; notes are persisted as text.
- Changes to the embedding model, retrieval thresholds, or the summarization algorithm.

## Further Notes

- The user's framing of "run long operations as subprocesses" is satisfied by owning the SSE stream subscriptions at app scope rather than per-page: keeping the HTTP connection alive across navigation prevents the backend generator from being cancelled, with no OS subprocess required.
- Each chunk already carries `Date` metadata derived from date headers in the journal text (formats like `YYYY-MM-DD` or `M/D/YYYY`); editor text without date headers parses to a single "Unknown Date" entry, which is why reference dates may be unknown and why per-row progress appeared stuck.
- The backend already implements `/notes/export/txt` and `/notes/export/docx`; the export work is primarily client wiring plus saving current content before export.
- Keying `/status` off the raw-notes file deliberately ties "notes exist" to "summary will work", preventing the class of bug where Q&A works but summary fails.
