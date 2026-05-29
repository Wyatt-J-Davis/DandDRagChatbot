"""Tests for NotePersistenceHandler."""
import pandas as pd
import pytest

from src.utils.NotePersistenceHandler import NotePersistenceHandler


def _make_handler(tmp_path):
    return NotePersistenceHandler(
        notes_file=str(tmp_path / "editor_notes.txt"),
        raw_notes_file=str(tmp_path / "raw_notes.json"),
    )


def _sample_df():
    return pd.DataFrame(
        {"Title": ["Entry for 2023-01-01"], "Date": ["2023-01-01"], "Contents": ["Some content."]}
    )


class TestPersist:
    def test_writes_raw_notes_json(self, tmp_path):
        handler = _make_handler(tmp_path)
        handler.persist(_sample_df(), "2023-01-01\nSome content.")
        assert (tmp_path / "raw_notes.json").exists()

    def test_raw_notes_json_is_readable_back_as_dataframe(self, tmp_path):
        handler = _make_handler(tmp_path)
        df = _sample_df()
        handler.persist(df, "2023-01-01\nSome content.")
        restored = pd.read_json(str(tmp_path / "raw_notes.json"))
        assert set(restored.columns) == {"Title", "Date", "Contents"}
        assert len(restored) == 1
        assert "Some content." in str(restored.iloc[0]["Contents"])

    def test_writes_editor_notes_txt(self, tmp_path):
        handler = _make_handler(tmp_path)
        handler.persist(_sample_df(), "some text content")
        assert (tmp_path / "editor_notes.txt").exists()
        assert (tmp_path / "editor_notes.txt").read_text(encoding="utf-8") == "some text content"

    def test_creates_data_directory_when_missing(self, tmp_path):
        handler = NotePersistenceHandler(
            notes_file=str(tmp_path / "subdir" / "editor_notes.txt"),
            raw_notes_file=str(tmp_path / "subdir" / "raw_notes.json"),
        )
        handler.persist(_sample_df(), "text")
        assert (tmp_path / "subdir" / "editor_notes.txt").exists()

    def test_overwrites_existing_notes_txt(self, tmp_path):
        handler = _make_handler(tmp_path)
        handler.persist(_sample_df(), "original content")
        handler.persist(_sample_df(), "updated content")
        assert (tmp_path / "editor_notes.txt").read_text(encoding="utf-8") == "updated content"


class TestReadNotesText:
    def test_returns_content_when_file_exists(self, tmp_path):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Campaign notes content.", encoding="utf-8")
        handler = _make_handler(tmp_path)
        assert handler.read_notes_text() == "Campaign notes content."

    def test_returns_empty_string_when_file_missing(self, tmp_path):
        handler = _make_handler(tmp_path)
        assert handler.read_notes_text() == ""


class TestHasNotes:
    def test_returns_true_when_raw_notes_file_exists(self, tmp_path):
        raw_notes = tmp_path / "raw_notes.json"
        raw_notes.write_text("{}", encoding="utf-8")
        handler = _make_handler(tmp_path)
        assert handler.has_notes() is True

    def test_returns_false_when_raw_notes_file_missing(self, tmp_path):
        handler = _make_handler(tmp_path)
        assert handler.has_notes() is False
