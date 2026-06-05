"""Unit tests for api_launcher path-resolution helpers."""
import os
import sys
import pytest


# ---------------------------------------------------------------------------
# Helpers to import the module fresh (it has no heavy deps at import time)
# ---------------------------------------------------------------------------

def _import_launcher():
    import importlib
    import api_launcher
    importlib.reload(api_launcher)
    return api_launcher


# ---------------------------------------------------------------------------
# _exe_dir
# ---------------------------------------------------------------------------

class TestExeDir:
    def test_returns_executable_dirname_when_bundled(self, monkeypatch, tmp_path):
        fake_exe = tmp_path / "bundle" / "ttrpg_backend.exe"
        fake_exe.parent.mkdir(parents=True, exist_ok=True)
        fake_exe.touch()

        monkeypatch.setattr(sys, "_MEIPASS", str(tmp_path / "bundle" / "_internal"), raising=False)
        monkeypatch.setattr(sys, "executable", str(fake_exe))

        m = _import_launcher()
        assert m._exe_dir() == str(fake_exe.parent)

    def test_returns_file_dir_when_not_bundled(self, monkeypatch):
        if hasattr(sys, "_MEIPASS"):
            monkeypatch.delattr(sys, "_MEIPASS")

        m = _import_launcher()
        expected = os.path.abspath(os.path.dirname(m.__file__))
        assert m._exe_dir() == expected


# ---------------------------------------------------------------------------
# _bundle_dir
# ---------------------------------------------------------------------------

class TestBundleDir:
    def test_returns_meipass_when_bundled(self, monkeypatch, tmp_path):
        meipass = str(tmp_path / "_internal")
        monkeypatch.setattr(sys, "_MEIPASS", meipass, raising=False)

        m = _import_launcher()
        assert m._bundle_dir() == meipass

    def test_returns_file_dir_when_not_bundled(self, monkeypatch):
        if hasattr(sys, "_MEIPASS"):
            monkeypatch.delattr(sys, "_MEIPASS")

        m = _import_launcher()
        expected = os.path.abspath(os.path.dirname(m.__file__))
        assert m._bundle_dir() == expected


# ---------------------------------------------------------------------------
# _sync_src
# ---------------------------------------------------------------------------

class TestSyncSrc:
    def test_does_nothing_when_dirs_are_equal(self, tmp_path):
        m = _import_launcher()
        # No exception, no copies
        m._sync_src(str(tmp_path), str(tmp_path))
        assert list(tmp_path.iterdir()) == []

    def test_copies_src_and_api_from_bundle_to_exe(self, tmp_path):
        bundle_dir = tmp_path / "bundle"
        exe_dir = tmp_path / "exe"
        bundle_dir.mkdir()
        exe_dir.mkdir()

        (bundle_dir / "src").mkdir()
        (bundle_dir / "src" / "utils.py").write_text("# src")
        (bundle_dir / "api").mkdir()
        (bundle_dir / "api" / "main.py").write_text("# api")

        m = _import_launcher()
        m._sync_src(str(exe_dir), str(bundle_dir))

        assert (exe_dir / "src" / "utils.py").exists()
        assert (exe_dir / "api" / "main.py").exists()

    def test_skips_folder_absent_from_bundle(self, tmp_path):
        bundle_dir = tmp_path / "bundle"
        exe_dir = tmp_path / "exe"
        bundle_dir.mkdir()
        exe_dir.mkdir()
        # only 'src' present in bundle, no 'api'
        (bundle_dir / "src").mkdir()

        m = _import_launcher()
        m._sync_src(str(exe_dir), str(bundle_dir))

        assert (exe_dir / "src").exists()
        assert not (exe_dir / "api").exists()

    def test_skips_folder_already_in_exe_dir(self, tmp_path):
        bundle_dir = tmp_path / "bundle"
        exe_dir = tmp_path / "exe"
        bundle_dir.mkdir()
        exe_dir.mkdir()

        (bundle_dir / "src").mkdir()
        (bundle_dir / "src" / "new.py").write_text("new")
        (exe_dir / "src").mkdir()
        (exe_dir / "src" / "old.py").write_text("old")

        m = _import_launcher()
        m._sync_src(str(exe_dir), str(bundle_dir))

        # existing exe/src must not be overwritten
        assert (exe_dir / "src" / "old.py").exists()
        assert not (exe_dir / "src" / "new.py").exists()


# ---------------------------------------------------------------------------
# _RotatingConsoleStream
# ---------------------------------------------------------------------------

class TestRotatingConsoleStream:
    def test_high_volume_writes_complete_without_blocking_and_file_rotates(self, tmp_path):
        """The original freeze was a blocking console write; writing to a regular
        rotating file must never block, so a large volume of writes simply
        completes (the test would hang on a regression) and stays size-bounded."""
        m = _import_launcher()
        log_path = tmp_path / "console.log"
        max_bytes = 1024
        line = "x" * 100 + "\n"

        stream = m._RotatingConsoleStream(str(log_path), max_bytes=max_bytes, backup_count=2)
        try:
            for _ in range(1000):  # ~101 KB written into a 1 KB-bounded file
                stream.write(line)
            stream.flush()
        finally:
            stream.close()

        # The active file never exceeds the size bound.
        assert log_path.exists()
        assert log_path.stat().st_size < max_bytes

        # Rotation happened and stayed bounded to backup_count backups.
        assert (tmp_path / "console.log.1").exists()
        for name in ("console.log.1", "console.log.2"):
            assert (tmp_path / name).stat().st_size <= max_bytes + len(line)
        assert not (tmp_path / "console.log.3").exists()

    def test_write_returns_number_of_characters(self, tmp_path):
        m = _import_launcher()
        stream = m._RotatingConsoleStream(str(tmp_path / "console.log"))
        try:
            assert stream.write("hello") == 5
        finally:
            stream.close()

    def test_is_not_a_tty(self, tmp_path):
        m = _import_launcher()
        stream = m._RotatingConsoleStream(str(tmp_path / "console.log"))
        try:
            assert stream.isatty() is False
        finally:
            stream.close()


# ---------------------------------------------------------------------------
# console redirection (packaged path only)
# ---------------------------------------------------------------------------

class TestConsoleRedirection:
    def test_redirect_points_stdout_and_stderr_at_rotating_file(self, monkeypatch, tmp_path):
        m = _import_launcher()
        log_path = tmp_path / "console.log"

        orig_stdout, orig_stderr = sys.stdout, sys.stderr
        stream = m._redirect_console_to_rotating_file(str(log_path))
        try:
            assert sys.stdout is stream
            assert sys.stderr is stream
            print("hello from redirected stdout")
            sys.stdout.flush()
            assert "hello from redirected stdout" in log_path.read_text(encoding="utf-8")
        finally:
            sys.stdout, sys.stderr = orig_stdout, orig_stderr
            stream.close()


# ---------------------------------------------------------------------------
# main() server start
# ---------------------------------------------------------------------------

class TestMainServerStart:
    def test_starts_server_with_access_log_disabled(self, monkeypatch, tmp_path):
        import uvicorn

        captured = {}

        def fake_run(*args, **kwargs):
            captured["args"] = args
            captured["kwargs"] = kwargs

        monkeypatch.setattr(uvicorn, "run", fake_run)

        m = _import_launcher()
        monkeypatch.setattr(m, "_exe_dir", lambda: str(tmp_path))
        monkeypatch.setattr(m, "_bundle_dir", lambda: str(tmp_path))
        monkeypatch.setattr(os, "chdir", lambda p: None)
        if hasattr(sys, "_MEIPASS"):
            monkeypatch.delattr(sys, "_MEIPASS")

        m.main()

        assert captured["kwargs"].get("access_log") is False

    def test_redirects_console_when_packaged(self, monkeypatch, tmp_path):
        import uvicorn

        monkeypatch.setattr(uvicorn, "run", lambda *a, **k: None)

        m = _import_launcher()
        monkeypatch.setattr(m, "_exe_dir", lambda: str(tmp_path))
        monkeypatch.setattr(m, "_bundle_dir", lambda: str(tmp_path))
        monkeypatch.setattr(os, "chdir", lambda p: None)
        monkeypatch.setattr(sys, "_MEIPASS", str(tmp_path), raising=False)

        called = {}
        monkeypatch.setattr(
            m, "_redirect_console_to_rotating_file",
            lambda *a, **k: called.setdefault("redirected", True),
        )

        m.main()

        assert called.get("redirected") is True

    def test_does_not_redirect_console_in_dev(self, monkeypatch, tmp_path):
        import uvicorn

        monkeypatch.setattr(uvicorn, "run", lambda *a, **k: None)

        m = _import_launcher()
        monkeypatch.setattr(m, "_exe_dir", lambda: str(tmp_path))
        monkeypatch.setattr(m, "_bundle_dir", lambda: str(tmp_path))
        monkeypatch.setattr(os, "chdir", lambda p: None)
        if hasattr(sys, "_MEIPASS"):
            monkeypatch.delattr(sys, "_MEIPASS")

        called = {}
        monkeypatch.setattr(
            m, "_redirect_console_to_rotating_file",
            lambda *a, **k: called.setdefault("redirected", True),
        )

        m.main()

        assert "redirected" not in called
