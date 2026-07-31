"""Unit tests for NoteEditor module-level utility functions — no Streamlit runtime."""

import pandas as pd

from src.app.NoteEditor import (
    strip_html,
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


class TestRawNotesToText:
    def test_returns_empty_when_input_empty(self):
        assert raw_notes_to_text("") == ""
        assert raw_notes_to_text(None) == ""

    def test_converts_entries_to_text(self):
        df = pd.DataFrame([{
            "Title": "Entry for 2023-10-27",
            "Date": "2023-10-27",
            "Contents": "The party fought goblins.",
        }])
        result = raw_notes_to_text(df.to_json())
        assert "<" not in result
        assert "2023-10-27" in result
        assert "The party fought goblins" in result

    def test_handles_corrupt_json(self):
        assert raw_notes_to_text("not json") == ""

    def test_multiple_entries_all_present(self):
        df = pd.DataFrame([
            {"Title": "Entry for 2023-01-01", "Date": "2023-01-01", "Contents": "First."},
            {"Title": "Entry for 2023-01-02", "Date": "2023-01-02", "Contents": "Second."},
        ])
        result = raw_notes_to_text(df.to_json())
        assert "2023-01-01" in result
        assert "2023-01-02" in result
        assert "First" in result
        assert "Second" in result

    def test_falls_back_to_title_when_date_unknown(self):
        df = pd.DataFrame([{
            "Title": "My Custom Title",
            "Date": "Unknown Date",
            "Contents": "Some content.",
        }])
        result = raw_notes_to_text(df.to_json())
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
