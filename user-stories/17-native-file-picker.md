# Issue 17: Native file picker for campaign notes upload

## What to build

Add a file picker button in the Q&A sidebar that opens a native Windows file dialog, filters to TXT, DOCX, and CSV files, and returns the absolute path of the selected file. The path is held in local state ready for the upload flow.

## Acceptance criteria

- [ ] "Upload Notes" button is visible in the Q&A sidebar
- [ ] Tapping the button opens the native Windows file picker dialog
- [ ] Dialog filters to `.txt`, `.docx`, and `.csv` files
- [ ] Selected file path is stored in local state and displayed (e.g. filename shown) after selection
- [ ] Cancelling the dialog does not change the current state

## Blocked by

- Issue 6: Navigation rail (Q&A page stub exists)
