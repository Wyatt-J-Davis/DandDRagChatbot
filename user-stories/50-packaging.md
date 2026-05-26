# Issue 50: Packaging: extend PyInstaller spec for FastAPI + Flutter build script

## What to build

Extend the existing `TTRPGChatbot.spec` and `build_exe.bat` to bundle the FastAPI backend into a standalone executable. Produce a Flutter Windows build. Write a top-level build script that outputs a single distributable folder containing both executables and all required assets. Streamlit and its dependencies are excluded from the bundle.

## Acceptance criteria

- [ ] `TTRPGChatbot.spec` bundles the FastAPI `api/` module and its dependencies
- [ ] Streamlit and all Streamlit-dependent packages are excluded from the PyInstaller bundle
- [ ] Flutter `flutter build windows --release` produces a working executable
- [ ] A top-level build script (e.g. `build_all.bat`) runs both builds and assembles a single distributable folder
- [ ] The distributable folder contains the Flutter exe, the Python/FastAPI exe, and all required assets
- [ ] Double-clicking the Flutter exe launches the app end-to-end without any manual setup

## Blocked by

All feature slices (Issues 1–44).
