"""
Entry point for the TTRPGChatbot FastAPI backend executable.

Starts the FastAPI/uvicorn server on localhost:8000. All data files
(data/, database/) are stored relative to the executable's directory.
"""
import os
import sys
import threading

_CONSOLE_LOG_FILE = "data/console.log"
_CONSOLE_LOG_MAX_BYTES = 5 * 1024 * 1024
_CONSOLE_LOG_BACKUP_COUNT = 3


class _RotatingConsoleStream:
    """A minimal file-like stream that writes to a size-rotating file on disk.

    The packaged backend's stdout/stderr are connected to an OS pipe the desktop
    app never drains; once that pipe's buffer fills, the next console write blocks
    the whole event loop forever. Redirecting console output here makes every write
    target a regular file (which cannot block on a full buffer) while keeping the
    on-disk size bounded via Python-level rotation.
    """

    def __init__(self, path: str, max_bytes: int = _CONSOLE_LOG_MAX_BYTES,
                 backup_count: int = _CONSOLE_LOG_BACKUP_COUNT):
        self._path = path
        self._max_bytes = max_bytes
        self._backup_count = backup_count
        self._lock = threading.Lock()
        log_dir = os.path.dirname(path)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        self._stream = open(path, "a", encoding="utf-8", errors="replace")

    def write(self, text: str) -> int:
        if not text:
            return 0
        with self._lock:
            self._stream.write(text)
            self._stream.flush()
            if self._stream.tell() >= self._max_bytes:
                self._rotate()
        return len(text)

    def _rotate(self) -> None:
        self._stream.close()
        if self._backup_count > 0:
            for i in range(self._backup_count - 1, 0, -1):
                src = f"{self._path}.{i}"
                dst = f"{self._path}.{i + 1}"
                if os.path.exists(src):
                    os.replace(src, dst)
            os.replace(self._path, f"{self._path}.1")
        self._stream = open(self._path, "a", encoding="utf-8", errors="replace")

    def flush(self) -> None:
        with self._lock:
            if not self._stream.closed:
                self._stream.flush()

    def isatty(self) -> bool:
        return False

    def close(self) -> None:
        with self._lock:
            if not self._stream.closed:
                self._stream.close()


def _redirect_console_to_rotating_file(path: str = _CONSOLE_LOG_FILE) -> _RotatingConsoleStream:
    stream = _RotatingConsoleStream(path)
    sys.stdout = stream
    sys.stderr = stream
    return stream


def _is_frozen() -> bool:
    return hasattr(sys, "_MEIPASS")


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

    # In the packaged exe, stdout/stderr feed an OS pipe the desktop app never
    # drains; send console output to a rotating file so a full pipe can never
    # wedge the event loop. The dev path keeps its real console untouched.
    if _is_frozen():
        _redirect_console_to_rotating_file()

    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    # Per-request HTTP logging is already handled by the operation-log middleware
    # in api.main; the uvicorn access log is redundant and the dominant source of
    # console-output volume, so it is disabled here.
    uvicorn.run("api.main:app", host="127.0.0.1", port=port, reload=False, access_log=False)


if __name__ == "__main__":
    main()
