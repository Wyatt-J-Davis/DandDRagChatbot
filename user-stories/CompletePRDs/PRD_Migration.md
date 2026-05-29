# PRD: Flutter Native Desktop Frontend Migration

## Problem Statement

The current app is built on Streamlit, a Python web-framework designed for data science prototypes. As a result, users experience a browser-based UI that feels generic, lacks native desktop affordances, and is constrained by Streamlit's re-execution model. Features like the rich-text note editor require complex JavaScript injection workarounds, progress streaming is limited to Streamlit's widget primitives, and the overall look cannot be meaningfully customized. Users who want a polished, native desktop experience for their TTRPG campaign tool are underserved by the current frontend.

## Solution

Replace the Streamlit frontend with a Flutter native Windows desktop application while keeping the existing Python business logic intact. A FastAPI layer will expose the existing handler classes (DatabaseHandler, LLMHandler, SummaryHandler) as HTTP endpoints with Server-Sent Events for streaming operations. Flutter will own the Python backend process lifecycle — launching it on startup and terminating it on exit. The result is a single double-click executable delivering a polished, native desktop experience with a Material 3 dark theme in deep purple.

## User Stories

1. As a player, I want the app to launch as a native Windows desktop window, so that it feels like a real application rather than a browser tab.
2. As a player, I want the app to start up without any manual backend setup, so that I can just double-click and start using it.
3. As a player, I want to see a loading state while the backend initializes, so that I know the app is starting rather than frozen.
4. As a player, I want a persistent left sidebar with page navigation icons and labels, so that I can switch between Q&A, Summary, and Note Editor at any time.
5. As a player, I want page-specific options (model selector, party members, etc.) to appear in a second panel next to the navigation rail, so that controls are always visible without cluttering the main content area.
6. As a player, I want to select a local Ollama model from a dropdown, so that I can choose which LLM powers my queries.
7. As a player, I want to adjust the model temperature with a slider, so that I can tune response creativity.
8. As a player, I want to add party member names to a list, so that the LLM knows who is in my campaign.
9. As a player, I want to designate one party member as the note-taker, so that the LLM understands whose perspective the notes are written from.
10. As a player, I want to remove party members from the list, so that I can keep the party roster accurate.
11. As a player, I want my model selection, temperature, and party member settings to persist between sessions, so that I do not have to reconfigure the app every time I open it.
12. As a player, I want to upload a campaign notes file (TXT, DOCX, or CSV) using a native file picker, so that I can populate the knowledge base.
13. As a player, I want to see a progress bar while my notes are being vectorized, so that I know the process is running and how far along it is.
14. As a player, I want to re-upload notes at any time to refresh the knowledge base, so that I can keep it up to date as the campaign progresses.
15. As a player, I want to type a question about the campaign in a chat input field, so that I can query my notes conversationally.
16. As a player, I want to see the LLM response appear in a chat bubble, so that the conversation feels natural.
17. As a player, I want to see reference buttons alongside each response, so that I can verify which note chunks the answer was drawn from.
18. As a player, I want to tap a reference button to open a popup showing the full note chunk text, so that I can read the source material.
19. As a player, I want the chat input to be disabled while the LLM is processing, so that I cannot submit another question before the current one finishes.
20. As a player, I want multi-turn chat history displayed in the conversation view, so that I can follow the context of the session.
21. As a player, I want to generate a campaign summary on demand, so that I can get a narrative overview of everything that has happened.
22. As a player, I want to see progress messages while the summary is being generated (map phase, reduce phase, final synthesis), so that I know the process is running.
23. As a player, I want to view the saved campaign summary with a table of contents, so that I can navigate long summaries easily.
24. As a player, I want to see metadata on the saved summary (model used, generation date), so that I know how fresh the summary is.
25. As a player, I want to regenerate the summary at any time, so that I can update it as the campaign progresses.
26. As a player, I want to edit my campaign notes in a rich-text editor with formatting options (bold, italic, headers, lists), so that my notes are readable and well-organized.
27. As a player, I want my note editor content to be saved automatically, so that I never lose work.
28. As a player, I want to toggle dark mode in the note editor, so that I can match my preference.
29. As a player, I want to import my uploaded notes into the editor, so that I can edit and refine them in place.
30. As a player, I want to vectorize my editor content to use it as the RAG knowledge base, so that my edited notes power the chatbot.
31. As a player, I want to export my notes as a plain TXT file, so that I can share or back them up.
32. As a player, I want to export my notes as a DOCX file, so that I can open them in Word or Google Docs.
33. As a player, I want navigation between pages or interaction with other UI elements to not interrupt long-running operations like inference or vectorization, so that I cannot accidentally interrupt vectorization or summary generation.
34. As a player, I want toast notifications when operations complete successfully, so that I get feedback without blocking the UI.
35. As a player, I want an error message if Ollama is not running or no models are available, so that I understand why the app is not responding.

## Implementation Decisions

### Architecture Overview

The system is split into two processes running on the same Windows machine:

- **Flutter desktop app** — native Windows executable, owns the user interface and process lifecycle.
- **FastAPI backend** — Python HTTP server running on localhost, wraps the existing handler classes with no internal changes.

Flutter launches the Python backend as a child process on startup, polls a `/health` endpoint until it responds, then shows the main UI. On exit, Flutter terminates the child process.

### Backend Layer (FastAPI)

A new `api/` module wraps the existing handler classes. The existing `DatabaseHandler`, `LLMHandler`, and `SummaryHandler` classes are used directly — no changes to their internals.

**Endpoints:**

| Method | Path | Response type | Handler |
|---|---|---|---|
| GET | `/health` | JSON | — |
| GET | `/models` | JSON | LLMHandler |
| POST | `/chat` | SSE stream | LLMHandler + DatabaseHandler |
| POST | `/upload-notes` | SSE stream | DatabaseHandler |
| GET | `/party` | JSON | user_data.json |
| POST | `/party` | JSON | user_data.json |
| POST | `/summary/generate` | SSE stream | SummaryHandler |
| GET | `/summary` | JSON | SummaryHandler |
| GET | `/notes` | JSON | editor_notes.txt |
| POST | `/notes` | JSON | editor_notes.txt |
| POST | `/notes/vectorize` | SSE stream | DatabaseHandler |
| GET | `/notes/export/txt` | File download | NoteEditor logic |
| GET | `/notes/export/docx` | File download | NoteEditor logic |

SSE events follow a consistent shape:
```
data: {"done": false, "progress": 42, "message": "Vectorizing chunk 3/7"}
data: {"done": true, "progress": 100, "result": "..."}
```

File operations use path sharing — Flutter sends an absolute file path string; FastAPI reads it directly from disk. This avoids multipart upload overhead and works because both processes run on the same machine.

`TextEditorHandler` and `NavigationHandler` are not ported to the backend — their responsibilities are absorbed entirely by Flutter widgets.

### Flutter Layer

**State management:** Riverpod. Each page has a dedicated `AsyncNotifier` or `StateNotifier`. SSE streams are consumed via `StreamProvider`. Shared state (selected model, party members) lives in a top-level `AppStateNotifier`.

**Navigation:** `NavigationRail` on the far left for page switching (3 destinations: Q&A, Summary, Note Editor). A second fixed-width panel to the right of the rail renders page-specific controls (model selector, temperature slider, party member list, sidebar buttons). The main content area fills the remaining space.

**Theme:** Material 3, dark mode, `deepPurple` seed color via `ColorScheme.fromSeed`.

**Process launcher:** A `BackendService` class handles spawning the Python process, polling `/health`, and terminating on app dispose. It exposes a `Future<void> ready` that the root widget awaits before rendering the main shell.

**Rich-text editor:** `flutter_quill` package. The editor widget wraps `QuillEditor` and `QuillToolbar`. Content is serialized to plain text (stripping delta markup) before being sent to the `/notes/vectorize` endpoint.

**File picker:** `file_picker` package for the native Windows file dialog. Returns an absolute path string that is sent directly to FastAPI.

**Chat UI:** A `ListView` of custom `ChatBubble` widgets (user / assistant variants). Each assistant bubble has a row of `ReferenceChip` widgets below it. Tapping a chip opens a `showDialog` with the full chunk text.

**Export downloads:** The `/notes/export/txt` and `/notes/export/docx` endpoints return file bytes; Flutter writes them to a user-selected save path via `file_picker`'s save dialog.

### Packaging

The existing PyInstaller workflow (`TTRPGChatbot.spec`, `build_exe.bat`) is extended to bundle the FastAPI backend into a standalone executable. Flutter's Windows build produces a separate executable that launches the Python process by path. A top-level build script produces a single distributable folder containing both executables and all required assets.

## Testing Decisions

**What makes a good test:** Tests should assert on observable behavior at module boundaries — HTTP responses, file system state, emitted SSE events — not on internal implementation details like which private method was called or how many times a handler was instantiated.

**Modules to test:**

- **FastAPI route layer** — each endpoint tested with `httpx.AsyncClient` and `TestClient`. Handlers are mocked at the boundary (injected as dependencies) so tests are fast and isolated. Prior art: the existing `tests/test_chatbot_unit.py` pattern of mocking `LLMHandler` and `DatabaseHandler`.
- **SSE streaming endpoints** — assert that the event stream emits the correct sequence of `done=false` progress events followed by a `done=true` terminal event.
- **`BackendService` (Flutter)** — unit tested with a mock HTTP server to verify startup polling logic and process lifecycle (launch, health check, teardown).
- **`AppStateNotifier` (Flutter)** — unit tested with `ProviderContainer` to verify that model selection, party member mutations, and persistence round-trips behave correctly.
- **Existing Python handler tests** — `test_database_handler.py`, `test_llm_handler.py`, `test_summary_handler.py` require no changes; the handlers themselves are not being modified.

**Modules not tested at unit level:**
- Flutter widget rendering (Q&A page, Summary page, Note Editor page) — verified via smoke test (run app, exercise golden paths manually).
- `flutter_quill` integration — tested manually; no unit tests for third-party widget internals.

## Out of Scope

- macOS and Linux desktop targets.
- Authentication or multi-user support.
- Remote Ollama instances (backend always assumes `localhost:11434`).
- Streaming LLM token-by-token output in the chat UI (responses arrive as a complete string from `LLMHandler.invoke_model`; streaming output is a future enhancement).
- Lottie animations (the Streamlit app used `st_lottie`; Flutter equivalents are deferred to a future polish pass).
- Any changes to `DatabaseHandler`, `LLMHandler`, or `SummaryHandler` internals.
- Cloud sync or backup of notes and summaries.
- The `auth/` directory (reserved, currently empty).

## Further Notes

- The `data/` directory structure and all JSON file formats remain unchanged. The FastAPI backend reads and writes the same files as the Streamlit app did.
- The existing `run_tests.bat` and all current pytest tests continue to pass unchanged — the migration adds a new `api/` module with its own tests rather than modifying existing ones.
- The branch for this work should be checked out from `main`. The current branch `flutter-refactor` appears to have been started already — confirm whether to continue on that branch or start fresh.
- Ollama must be installed and running independently. The app should surface a clear error state (not crash) if Ollama is unreachable on startup.
- The PyInstaller build should exclude Streamlit and all Streamlit-dependent packages from the bundled executable once the migration is complete, reducing bundle size significantly.
