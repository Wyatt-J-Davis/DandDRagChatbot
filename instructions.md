Previous commits:
c0603ca3515672cf615b210fa76014e583926be9
2026-05-27
Issue 26: Move story file to done/
---
00f7e4eb6f538884b8fa14e235bfbc8d40201060
2026-05-27
Issue 26: Reference chip popup: full note chunk text

Files changed:
- ui/lib/pages/qa_page.dart: added _showSourceDialog method that calls showDialog with an AlertDialog; content wrapped in SingleChildScrollView for long chunks; Close TextButton dismisses via Navigator.pop; onTap wired on each ReferenceChip passing the corresponding sources[i] string
- ui/test/pages/qa_page_test.dart: 4 new tests: tapping chip opens dialog, dialog displays source chunk text, close button dismisses dialog, dialog content is scrollable (SingleChildScrollView)

Key decisions:
- Dialog built entirely in QAPage (_showSourceDialog) so ReferenceChip stays a pure display widget with no context dependency
- AlertDialog with SingleChildScrollView satisfies scrollability requirement without needing a custom scroll widget
- Close action uses Navigator.of(context).pop() on the QAPage context - works correctly because the dialog route is on the same navigator

All 190 Flutter tests and 308 Python tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
078f52f18741274b6ca4d16fde090609c0bd23f2
2026-05-27
Issue 25: Reference chips alongside assistant response

Files changed:
- ui/lib/widgets/reference_chip.dart: new ReferenceChip widget wrapping ActionChip; labeled "Source N" (1-based index); accepts optional onTap callback (action wired in Issue 26)
- ui/test/widgets/reference_chip_test.dart: 4 tests covering label for index 1, label for index 2, onTap invoked on tap, renders without onTap
- ui/lib/pages/qa_page.dart: _ChatMessage gains sources field (List<String>, default []); _submit() passes event.sources to assistant _ChatMessage on ChatAnswerEvent; itemBuilder wraps ChatBubble in Column and conditionally renders Padding > Wrap > ReferenceChip row below assistant bubbles when sources non-empty
- ui/test/pages/qa_page_test.dart: added _SourcedAnswerChatService mock; 4 new tests: chips appear with sources, chip labels match "Source 1"/"Source 2", no chips when sources empty, no chips for user messages; ReferenceChip import added

Key decisions:
- ReferenceChip uses Flutter ActionChip so it is tappable with a single onPressed hook; no visual customisation needed for Issue 25 (Issue 26 wires the action)
- Chip row placed in QAPage itemBuilder (not ChatBubble) so ChatBubble stays a pure message widget with no layout knowledge of siblings
- Chips only rendered for ChatSender.assistant messages with non-empty sources, so user bubbles and error bubbles are unaffected
- Wrap widget used for chip row to handle overflow if many sources are returned

All 186 Flutter tests and 308 Python tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
6d23129f56e0612cea7da664ea2cb6ad4ac18108
2026-05-27
Issue 24: Multi-turn chat history in conversation view

The implementation from Issue 23 already accumulated messages correctly
(_messages list is appended to, never cleared; _scrollToBottom called after
each response). This story adds tests that explicitly verify the multi-turn
contract so the behavior is protected going forward.

Files changed:
- ui/test/pages/qa_page_test.dart: two new tests — 'four bubbles visible
  after two question-answer cycles' (findsNWidgets(4)) and 'prior messages
  remain visible after second submission' (first question, second question,
  and both answer texts all findable after two submits)

All 178 Flutter tests and 308 Python tests pass.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---
d8ce88893e0e2d91e998652817cda1a11352f66c
2026-05-27
Issue 23: Move story file to done/

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
---

User Story:
# Issue 29: Summary generation progress messages (map / reduce / synthesis)

## What to build

Wire the Summary page "Generate" button to the `/summary/generate` endpoint and display the incoming SSE progress messages so the user knows which phase is running.

## Acceptance criteria

- [ ] Tapping "Generate Summary" sends a POST `/summary/generate` request with the current model and party members
- [ ] Each incoming SSE `message` value is displayed on the Summary page as the stream progresses
- [ ] Phase labels (map, reduce, synthesis) are shown distinctly
- [ ] When the `done: true` event arrives, the progress display is replaced by the summary view (Issue 31)
- [ ] Generate button is disabled while generation is in progress

## Blocked by

- Issue 28: `/summary/generate` SSE endpoint

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
