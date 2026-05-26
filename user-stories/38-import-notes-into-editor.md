# Issue 38: Import uploaded notes into editor

## What to build

Add an "Import" button in the Note Editor sidebar that reads the last uploaded notes file and loads its plain-text content into the Quill editor, so the user can edit and refine their uploaded notes in place.

## Acceptance criteria

- [ ] "Import" button is visible in the Note Editor sidebar
- [ ] Tapping it loads the content of the last uploaded notes file into the Quill editor
- [ ] Existing editor content is replaced (with a confirmation prompt if content is non-empty)
- [ ] If no file has been uploaded in the current session, the button is disabled with a tooltip

## Blocked by

- Issue 34: `flutter_quill` editor widget
- Issue 17: Native file picker (upload path is available in app state)
