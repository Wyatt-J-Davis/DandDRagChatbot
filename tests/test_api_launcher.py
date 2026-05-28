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
