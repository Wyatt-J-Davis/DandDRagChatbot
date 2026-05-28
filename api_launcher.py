"""
Entry point for the TTRPGChatbot FastAPI backend executable.

Starts the FastAPI/uvicorn server on localhost:8000. All data files
(data/, database/) are stored relative to the executable's directory.
"""
import os
import sys


def _exe_dir() -> str:
    if hasattr(sys, "_MEIPASS"):
        return os.path.dirname(sys.executable)
    return os.path.abspath(os.path.dirname(__file__))


def _bundle_dir() -> str:
    return getattr(sys, "_MEIPASS", os.path.abspath(os.path.dirname(__file__)))


def _sync_src(exe_dir: str, bundle_dir: str) -> None:
    """Copy api/ and src/ from the bundle to the exe directory when they diverge (PyInstaller >= 6)."""
    if bundle_dir == exe_dir:
        return
    import shutil
    for folder in ("src", "api"):
        src = os.path.join(bundle_dir, folder)
        dst = os.path.join(exe_dir, folder)
        if os.path.isdir(src) and not os.path.isdir(dst):
            shutil.copytree(src, dst)


def main() -> None:
    exe_dir = _exe_dir()
    bundle_dir = _bundle_dir()

    os.chdir(exe_dir)
    _sync_src(exe_dir, bundle_dir)

    for path in (exe_dir, bundle_dir):
        if path not in sys.path:
            sys.path.insert(0, path)

    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("api.main:app", host="127.0.0.1", port=port, reload=False)


if __name__ == "__main__":
    main()
