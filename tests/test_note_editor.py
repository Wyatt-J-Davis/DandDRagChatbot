"""Unit tests for NoteEditor module-level utility functions — no Streamlit runtime."""

import io
import os
import pytest
import pandas as pd
from unittest.mock import patch

from src.app.NoteEditor import (
    strip_html,
    load_editor_notes,
    save_editor_notes,
    load_editor_settings,
    save_editor_settings,
    raw_notes_to_text,
    build_txt_content,
    build_docx_bytes,
    _EditorDocument,
)


class TestStripHtml:
    def test_strips_paragraph_tags(self):
        assert strip_html("<p>Hello world</p>") == "Hello world"

    def test_strips_heading_tags(self):
        result = strip_html("<h2>Title</h2><p>Body</p>")
        assert "Title" in result
        assert "Body" in result

    def test_empty_string(self):
        assert strip_html("") == ""

    def test_none_treated_as_empty(self):
        assert strip_html(None) == ""

    def test_plain_text_passthrough(self):
        assert strip_html("plain text") == "plain text"

    def test_nested_tags(self):
        result = strip_html("<p><strong>bold</strong> text</p>")
        assert "bold" in result
        assert "text" in result

    def test_multiple_paragraphs(self):
        result = strip_html("<p>First</p><p>Second</p>")
        assert "First" in result
        assert "Second" in result


class TestLoadEditorNotes:
    def test_returns_empty_when_file_absent(self, tmp_path):
        assert load_editor_notes(str(tmp_path / "nonexistent.txt")) == ""

    def test_returns_file_content(self, tmp_path):
        f = tmp_path / "notes.txt"
        f.write_text("My notes", encoding="utf-8")
        assert load_editor_notes(str(f)) == "My notes"

    def test_returns_empty_on_read_error(self, tmp_path):
        f = tmp_path / "notes.txt"
        f.write_text("content", encoding="utf-8")
        with patch("builtins.open", side_effect=OSError("permission denied")):
            assert load_editor_notes(str(f)) == ""


class TestSaveEditorNotes:
    def test_creates_file_with_content(self, tmp_path):
        filepath = str(tmp_path / "notes.txt")
        save_editor_notes(filepath, "saved content")
        with open(filepath, "r", encoding="utf-8") as f:
            assert f.read() == "saved content"

    def test_saves_empty_string(self, tmp_path):
        filepath = str(tmp_path / "notes.txt")
        save_editor_notes(filepath, "")
        with open(filepath, "r", encoding="utf-8") as f:
            assert f.read() == ""

    def test_saves_none_as_empty(self, tmp_path):
        filepath = str(tmp_path / "notes.txt")
        save_editor_notes(filepath, None)
        with open(filepath, "r", encoding="utf-8") as f:
            assert f.read() == ""

    def test_creates_missing_parent_directory(self, tmp_path):
        filepath = str(tmp_path / "subdir" / "notes.txt")
        save_editor_notes(filepath, "content")
        assert os.path.isfile(filepath)


class TestLoadEditorSettings:
    def test_returns_empty_dict_when_file_absent(self, tmp_path):
        assert load_editor_settings(str(tmp_path / "nonexistent.json")) == {}

    def test_returns_saved_settings(self, tmp_path):
        f = tmp_path / "settings.json"
        f.write_text('{"dark_mode": true}', encoding="utf-8")
        assert load_editor_settings(str(f)) == {"dark_mode": True}

    def test_returns_empty_dict_on_corrupt_json(self, tmp_path):
        bad = tmp_path / "settings.json"
        bad.write_text("not json", encoding="utf-8")
        assert load_editor_settings(str(bad)) == {}

    def test_returns_empty_dict_when_json_is_not_an_object(self, tmp_path):
        f = tmp_path / "settings.json"
        f.write_text("[1, 2, 3]", encoding="utf-8")
        assert load_editor_settings(str(f)) == {}

    def test_returns_empty_dict_on_read_error(self, tmp_path):
        f = tmp_path / "settings.json"
        f.write_text('{"dark_mode": true}', encoding="utf-8")
        with patch("builtins.open", side_effect=OSError("permission denied")):
            assert load_editor_settings(str(f)) == {}


class TestSaveEditorSettings:
    def test_round_trips_dark_mode_true(self, tmp_path):
        filepath = str(tmp_path / "settings.json")
        save_editor_settings(filepath, {"dark_mode": True})
        assert load_editor_settings(filepath) == {"dark_mode": True}

    def test_round_trips_dark_mode_false(self, tmp_path):
        filepath = str(tmp_path / "settings.json")
        save_editor_settings(filepath, {"dark_mode": False})
        assert load_editor_settings(filepath) == {"dark_mode": False}

    def test_saves_none_as_empty_object(self, tmp_path):
        filepath = str(tmp_path / "settings.json")
        save_editor_settings(filepath, None)
        assert load_editor_settings(filepath) == {}

    def test_creates_missing_parent_directory(self, tmp_path):
        filepath = str(tmp_path / "subdir" / "settings.json")
        save_editor_settings(filepath, {"dark_mode": True})
        assert os.path.isfile(filepath)

    def test_overwrites_existing_settings(self, tmp_path):
        filepath = str(tmp_path / "settings.json")
        save_editor_settings(filepath, {"dark_mode": True})
        save_editor_settings(filepath, {"dark_mode": False})
        assert load_editor_settings(filepath) == {"dark_mode": False}

    def test_preserves_unrelated_keys_on_round_trip(self, tmp_path):
        filepath = str(tmp_path / "settings.json")
        save_editor_settings(filepath, {"dark_mode": True, "future_option": "x"})
        loaded = load_editor_settings(filepath)
        assert loaded == {"dark_mode": True, "future_option": "x"}


class TestRawNotesToText:
    def test_returns_empty_when_file_absent(self, tmp_path):
        assert raw_notes_to_text(str(tmp_path / "missing.json")) == ""

    def test_converts_entries_to_text(self, tmp_path):
        df = pd.DataFrame([{
            "Title": "Entry for 2023-10-27",
            "Date": "2023-10-27",
            "Contents": "The party fought goblins.",
        }])
        json_path = str(tmp_path / "raw_notes.json")
        df.to_json(json_path)
        result = raw_notes_to_text(json_path)
        assert "<" not in result
        assert "2023-10-27" in result
        assert "The party fought goblins" in result

    def test_handles_corrupt_json(self, tmp_path):
        bad = tmp_path / "bad.json"
        bad.write_text("not json", encoding="utf-8")
        assert raw_notes_to_text(str(bad)) == ""

    def test_multiple_entries_all_present(self, tmp_path):
        df = pd.DataFrame([
            {"Title": "Entry for 2023-01-01", "Date": "2023-01-01", "Contents": "First."},
            {"Title": "Entry for 2023-01-02", "Date": "2023-01-02", "Contents": "Second."},
        ])
        json_path = str(tmp_path / "raw_notes.json")
        df.to_json(json_path)
        result = raw_notes_to_text(json_path)
        assert "2023-01-01" in result
        assert "2023-01-02" in result
        assert "First" in result
        assert "Second" in result

    def test_falls_back_to_title_when_date_unknown(self, tmp_path):
        df = pd.DataFrame([{
            "Title": "My Custom Title",
            "Date": "Unknown Date",
            "Contents": "Some content.",
        }])
        json_path = str(tmp_path / "raw_notes.json")
        df.to_json(json_path)
        result = raw_notes_to_text(json_path)
        assert "My Custom Title" in result


class TestBuildTxtContent:
    def test_returns_plain_text_unchanged(self):
        result = build_txt_content("Title\nBody text.")
        assert result == "Title\nBody text."

    def test_empty_content(self):
        assert build_txt_content("") == ""

    def test_multiline_content(self):
        content = "Line one\nLine two\nLine three"
        assert build_txt_content(content) == content


class TestBuildDocxBytes:
    def test_returns_bytes(self):
        result = build_docx_bytes("Hello world")
        assert isinstance(result, bytes)
        assert len(result) > 0

    def test_docx_is_zip_archive(self):
        result = build_docx_bytes("Content")
        assert result[:2] == b"PK"

    def test_empty_content_still_returns_valid_docx(self):
        result = build_docx_bytes("")
        assert isinstance(result, bytes)
        assert result[:2] == b"PK"

    def test_multiline_content(self):
        result = build_docx_bytes("Chapter One\nText here.")
        assert isinstance(result, bytes)
        assert len(result) > 0


class TestEditorDocument:
    def test_name_is_txt(self):
        doc = _EditorDocument("hello")
        assert doc.name == "editor_notes.txt"

    def test_getvalue_returns_utf8_bytes(self):
        doc = _EditorDocument("hello")
        assert doc.getvalue() == b"hello"

    def test_read_returns_utf8_bytes(self):
        doc = _EditorDocument("test content")
        assert doc.read() == b"test content"

    def test_unicode_content_encoded(self):
        doc = _EditorDocument("café résumé")
        assert doc.getvalue() == "café résumé".encode("utf-8")
