Previous commits:
bdfc36f1d53017bd9f318dd813e0cd95eed882da
2026-05-29
Issue 51: Bundle Lottie assets + add lottie dependency

Files changed:
- ui/assets/Magical_Effect_Loading.json: copied from project assets/ into Flutter asset bundle
- ui/assets/star-magic.json: copied from project assets/ into Flutter asset bundle
- ui/pubspec.yaml: added lottie: ^3.1.0 dependency; declared both JSON assets under flutter.assets
- ui/pubspec.lock: updated — lottie 3.3.3 resolved (archive, posix added as transitive deps)
- ui/test/widgets/lottie_assets_test.dart: 2 widget tests — each loads the respective Lottie.asset() and pumps one frame, verifying no exception is thrown
- user-stories/done/51-bundle-lottie-assets.md: moved from open/

Key decisions:
- No LottiePlayer wrapper widget created here; Issues 58 and 60 will build the actual
  widgets that consume these assets in context, avoiding premature abstraction
- lottie: ^3.1.0 resolves to 3.3.3 which is the current stable release
- Asset paths declared as assets/Magical_Effect_Loading.json and assets/star-magic.json
  matching the expected paths the later slices will reference per PRD

All 290 Flutter tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
afe8cd826a689dbe88c8109daf0ef2904bf0143d
2026-05-28
Issue 50: Packaging — FastAPI PyInstaller spec + Flutter build script

Files changed:
- api_launcher.py: new PyInstaller entry point; starts uvicorn on port 8000;
  handles _MEIPASS path resolution (same pattern as launcher.py); copies src/
  and api/ from bundle to exe dir when PyInstaller >= 6 separates them
- TTRPGChatbot.spec: repurposed for FastAPI backend; entry point changed from
  launcher.py to api_launcher.py; removed all Streamlit/Altair/pyarrow/
  streamlit_quill/streamlit_lottie; added uvicorn/FastAPI/pydantic/h11/
  starlette hidden imports; output renamed ttrpg_backend
- build_exe.bat: updated path reference from TTRPGChatbot.exe to ttrpg_backend.exe
- build_all.bat: new top-level script that (1) runs PyInstaller, (2) runs
  flutter build windows --release in ui/, (3) assembles dist\TTRPGChatbotApp\
  with Flutter exe at root and PyInstaller output under backend\
- tests/test_api_launcher.py: 8 tests covering _exe_dir/_bundle_dir in bundled
  vs dev mode, and _sync_src copy/skip behaviour
- user-stories/done/50-packaging.md: moved from open/

Key decisions:
- Streamlit and all its dependencies (altair, pyarrow, tornado) excluded from
  the bundle; the Flutter UI is now the sole frontend
- Backend exe placed at backend\ttrpg_backend.exe matching the path expected
  by BackendService in ui/lib/main.dart
- xcopy used for assembly (universally available on Windows, no extra tooling)

All 316 tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
1f951b0b0b37068ea2b47da595d4d6f11e9949a6
2026-05-28
Issue 49: Flutter unit tests: AppStateNotifier (model, temperature, party persistence)

All acceptance criteria were already satisfied by tests written during the
implementation of the dependency stories (Issues 12-16). No new code was
needed.

Files changed:
- ui/test/state/app_state_notifier_test.dart: pre-existing; 39 tests covering
  all 7 acceptance criteria (model/temperature mutation, party add/remove,
  note-taker designation, persistence write via _FakePrefsService,
  initialisation from stored preferences)
- user-stories/done/49-flutter-tests-app-state-notifier.md: moved story to done/

Key decisions:
- Story referenced ProviderContainer (Riverpod), but the project uses
  ChangeNotifier with manual DI; existing pattern already covers all requirements
- Load-from-file criterion is satisfied by the initialisation-from-stored-preferences
  group, which mirrors the real main.dart flow (load then pass to constructor)

All 288 Flutter tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
0e943939e1cc24ffe6585da3a7ebb04762906400
2026-05-28
Issue 48: Flutter unit tests: BackendService (mock HTTP server)

Tests were already implemented in a prior commit (51facbb) alongside the
BackendService implementation. This commit closes the story by moving it
to done/.

Files changed:
- ui/test/services/backend_service_test.dart: 5 tests covering ready resolves
  on HTTP 200, polling retries on non-200, polling retries on connection error,
  dispose() kills the child process, executablePath forwarded to ProcessStarter
- user-stories/done/48-flutter-tests-backend-service.md: moved from open/

All 288 Flutter tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
c4c39ab0b5fc91ef21641ff39949babc31320059
2026-05-28
Issue 44: Toast notifications on operation completion

Files changed:
- ui/lib/widgets/notes_upload_button.dart: added ScaffoldMessenger.showSnackBar on UploadDoneEvent
- ui/lib/pages/summary_page.dart: added ScaffoldMessenger.showSnackBar on SummaryDoneEvent
- ui/lib/widgets/vectorize_button.dart: added ScaffoldMessenger.showSnackBar on VectorizeDoneEvent
- ui/test/widgets/notes_upload_button_test.dart: 2 new tests (toast on success, no toast on error)
- ui/test/pages/summary_page_test.dart: 2 new tests (toast on success, no toast on error)
- ui/test/widgets/vectorize_button_test.dart: 2 new tests (toast on success, no toast on error)
- user-stories/done/44-toast-notifications.md: moved story to done/

Key decisions:
- ScaffoldMessenger used directly in State.context; existing mounted guards protect each call site
- Default SnackBar duration (4s) satisfies auto-dismiss requirement
- No new parameters or abstractions; toast is a one-liner at the done-event branch in each widget
- Errors continue using existing inline red text; no SnackBar on error paths

All 288 Flutter tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---

User Story:
# Issue 53: `/status` endpoint + startup notes detection

**Type:** AFK

## What to build

A backend `/status` endpoint that reports whether notes exist, keyed off the presence of the raw-notes file (the same artifact the summarizer requires, so status can't drift out of sync with summary availability). On launch the Flutter client calls `/status` and uses the result so the Q&A page offers "Re-upload notes" instead of "Upload" when notes already exist. This fixes the bug where a restart made the app act as if no notes were vectorized.

Response shape: `{ "has_notes": boolean }`.

See `PRD.md` ("`/status` endpoint", user stories 1–2) for high-level decisions.

## Acceptance criteria

- [ ] `GET /status` returns `{ "has_notes": boolean }` based on the raw-notes file's existence
- [ ] The Flutter client queries `/status` on launch and stores the `has_notes` flag in app state
- [ ] When `has_notes` is true, the Q&A page shows "Re-upload notes"; otherwise "Upload notes"
- [ ] The flag is correct across restarts (notes vectorized in a prior run are detected)
- [ ] `/status` is covered by a backend test (notes present vs absent)

## Blocked by

- Issue 52: Persist canonical notes on vectorize

# AFK Development Session

You have been given the last 5 commit messages and a single user story to implement.

## Your Task

Implement the user story provided above. Work on nothing else.

If the story is marked `HITL`, output `<promise>NO MORE TASKS</promise>` and stop.

Follow these steps exactly:

## 1. Explore

Review the commit messages to understand recent work. Explore the repo structure so you understand the codebase before touching anything.

## 2. Understand

Read the story fully. If it is blocked by an incomplete dependency, output `<promise>NO MORE TASKS</promise>` and stop.

## 3. Implement (TDD)

Use /tdd to implement the story.

- Write failing tests first.
- Make them pass.
- Refactor.

## 4. Feedback loop

Before committing:

1. Run all unit tests — fix any failures.
2. Smoke-test the app (no compilation errors or runtime exceptions) — fix any issues.

Do not commit until both pass cleanly.

## 5. Commit

Make a single git commit. The message must include:

1. Key decisions made
2. Files changed
3. Any blockers or notes for the next iteration

## 6. Close the story

- If the task is **complete**: move the story file to `user-stories/done/`.
- If the task is **incomplete**: add a note to the story file describing what was done and what remains.

## Final Rules

- **Only work on one story per session.**
- Do not open PRs or push — the developer handles that.
