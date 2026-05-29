# Issue 61: Notes export to txt/docx

**Type:** AFK

## What to build

Let the user export their notes to a file, like the Streamlit version. Add txt and docx export controls at the top of the note editor. Each opens a native Save-As dialog so the user picks the destination; the app fetches the bytes from the existing backend export endpoints and writes them there. Before exporting, save the current editor content so the export reflects current text rather than stale saved text.

The backend already serves `/notes/export/txt` and `/notes/export/docx`; this slice is primarily client wiring plus save-before-export.

See `PRD.md` ("Notes unification" export item, user stories 16, 32) for high-level decisions.

## Acceptance criteria

- [ ] The note editor exposes txt and docx export controls at the top of the page
- [ ] Each export opens a native Save-As dialog for the destination
- [ ] The app fetches bytes from the backend export endpoint and writes them to the chosen path
- [ ] Current editor content is saved before export so output is not stale
- [ ] Exported txt and docx files contain the current notes content

## Blocked by

- Issue 52: Persist canonical notes on vectorize
