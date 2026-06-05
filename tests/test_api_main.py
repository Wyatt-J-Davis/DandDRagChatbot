"""Tests for the FastAPI application skeleton, /health, /models, and /upload-notes endpoints."""
import json
import threading
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

import pandas as pd

from api.main import create_app, get_llm_handler, get_db_handler, get_persistence_handler, get_summary_handler
from src.utils.DatabaseHandler import DATABASE_DIR


@pytest.fixture
def client():
    return TestClient(create_app())


def _make_mock_handler(model_names: list[str]) -> MagicMock:
    handler = MagicMock()
    models = []
    for name in model_names:
        m = MagicMock()
        m.model = name
        models.append(m)
    handler.get_available_models.return_value = models
    return handler


class TestHealth:
    def test_returns_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200

    def test_returns_status_ok(self, client):
        response = client.get("/health")
        assert response.json() == {"status": "ok"}


class TestUnknownRoute:
    def test_returns_404(self, client):
        response = client.get("/nonexistent")
        assert response.status_code == 404


class TestModelsEndpoint:
    def _client_with_handler(self, handler):
        app = create_app()
        app.dependency_overrides[get_llm_handler] = lambda: handler
        return TestClient(app)

    def test_returns_200(self):
        client = self._client_with_handler(_make_mock_handler(["llama3:latest"]))
        response = client.get("/models")
        assert response.status_code == 200

    def test_returns_model_names_as_string_array(self):
        client = self._client_with_handler(_make_mock_handler(["llama3:latest", "mistral:7b"]))
        response = client.get("/models")
        assert response.json() == ["llama3:latest", "mistral:7b"]

    def test_returns_empty_array_when_no_models(self):
        client = self._client_with_handler(_make_mock_handler([]))
        response = client.get("/models")
        assert response.status_code == 200
        assert response.json() == []


def _parse_sse_events(response_text: str) -> list[dict]:
    """Parse SSE response body into a list of parsed JSON data objects."""
    events = []
    for block in response_text.split("\n\n"):
        block = block.strip()
        if not block:
            continue
        for line in block.splitlines():
            if line.startswith("data: "):
                events.append(json.loads(line[len("data: "):]))
    return events


class TestUploadNotesEndpoint:
    def _client_with_db(self, db_handler):
        app = create_app()
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        return TestClient(app)

    def _make_db_handler(self, progress_values: list[float]):
        handler = MagicMock()
        handler.generate_database.return_value = iter(progress_values)
        return handler

    def _make_erroring_db_handler(self):
        handler = MagicMock()
        handler.generate_database.side_effect = RuntimeError("disk full")
        return handler

    def test_returns_200(self):
        client = self._client_with_db(self._make_db_handler([50.0, 100.0]))
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        assert response.status_code == 200

    def test_content_type_is_event_stream(self):
        client = self._client_with_db(self._make_db_handler([50.0]))
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        assert "text/event-stream" in response.headers["content-type"]

    def test_emits_progress_events_before_done(self):
        client = self._client_with_db(self._make_db_handler([33.0, 66.0, 100.0]))
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        events = _parse_sse_events(response.text)
        progress_events = [e for e in events if not e.get("done")]
        assert len(progress_events) >= 1

    def test_terminal_event_has_done_true_and_progress_100(self):
        client = self._client_with_db(self._make_db_handler([50.0]))
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        events = _parse_sse_events(response.text)
        terminal = events[-1]
        assert terminal["done"] is True
        assert terminal["progress"] == 100

    def test_intermediate_events_have_done_false(self):
        client = self._client_with_db(self._make_db_handler([25.0, 50.0, 75.0]))
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        events = _parse_sse_events(response.text)
        for event in events[:-1]:
            assert event["done"] is False

    def test_intermediate_events_have_message_field(self):
        client = self._client_with_db(self._make_db_handler([50.0]))
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        events = _parse_sse_events(response.text)
        progress_events = [e for e in events if not e.get("done")]
        for event in progress_events:
            assert "message" in event
            assert "progress" in event

    def test_error_emits_sse_error_event_not_http_500(self):
        client = self._client_with_db(self._make_erroring_db_handler())
        response = client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        assert response.status_code == 200
        events = _parse_sse_events(response.text)
        error_events = [e for e in events if e.get("error")]
        assert len(error_events) >= 1

    def test_clears_database_before_generating_to_replace_not_append(self):
        handler = self._make_db_handler([100.0])
        client = self._client_with_db(handler)
        client.post("/upload-notes", json={"file_path": "/tmp/notes.txt"})
        handler.clear_database.assert_called_once_with(DATABASE_DIR)

    def test_persists_raw_and_editor_notes_after_successful_upload(self, tmp_path):
        notes_file = tmp_path / "notes.txt"
        notes_file.write_text("2023-01-01\nSome campaign notes.", encoding="utf-8")

        df = pd.DataFrame({"Title": ["Entry"], "Date": ["2023-01-01"], "Contents": ["Some campaign notes."]})
        db_handler = MagicMock()
        db_handler.generate_database.return_value = iter([100.0])
        db_handler.last_processed_df = df

        persistence = MagicMock()

        app = create_app()
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        app.dependency_overrides[get_persistence_handler] = lambda: persistence
        client = TestClient(app)
        client.post("/upload-notes", json={"file_path": str(notes_file)})

        persistence.persist.assert_called_once()
        call_args = persistence.persist.call_args[0]
        assert call_args[0] is df
        assert "2023-01-01" in call_args[1]
        assert "Some campaign notes." in call_args[1]

    def test_does_not_persist_when_upload_errors(self, tmp_path):
        persistence = MagicMock()
        db_handler = MagicMock()
        db_handler.generate_database.side_effect = RuntimeError("disk full")

        app = create_app()
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        app.dependency_overrides[get_persistence_handler] = lambda: persistence
        client = TestClient(app)
        client.post("/upload-notes", json={"file_path": str(tmp_path / "notes.txt")})

        persistence.persist.assert_not_called()


def _make_mock_doc(content: str, date: str = "2023-10-27") -> MagicMock:
    doc = MagicMock()
    doc.page_content = content
    doc.metadata = {"Date": date}
    return doc


class TestChatEndpoint:
    _CHAT_BODY = {"question": "What happened?", "model": "llama3", "temperature": 0.7}

    def _client_with_handlers(self, llm_handler, db_handler):
        app = create_app()
        app.dependency_overrides[get_llm_handler] = lambda: llm_handler
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        return TestClient(app)

    def _make_handlers(self, answer="The dragon attacked", sources=None):
        if sources is None:
            sources = ["Dragons raided the village on day 3."]
        llm = MagicMock()
        llm.invoke_model.return_value = answer
        db = MagicMock()
        db.retrieve_notes.return_value = [_make_mock_doc(s) for s in sources]
        return llm, db

    # --- tracer bullet ---

    def test_terminal_event_has_done_answer_sources(self):
        llm, db = self._make_handlers()
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        events = _parse_sse_events(response.text)
        terminal = events[-1]
        assert terminal["done"] is True
        assert "answer" in terminal
        assert "sources" in terminal

    def test_returns_200_with_event_stream_content_type(self):
        llm, db = self._make_handlers()
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        assert response.status_code == 200
        assert "text/event-stream" in response.headers["content-type"]

    def test_emits_progress_events_before_terminal(self):
        llm, db = self._make_handlers()
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        events = _parse_sse_events(response.text)
        assert len(events) >= 2
        for event in events[:-1]:
            assert event["done"] is False

    def test_sources_match_retrieved_chunk_text(self):
        llm, db = self._make_handlers(sources=["Chunk A", "Chunk B"])
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        events = _parse_sse_events(response.text)
        sources = events[-1]["sources"]
        assert [s["content"] for s in sources] == ["Chunk A", "Chunk B"]

    def test_sources_include_date_metadata(self):
        llm = MagicMock()
        llm.invoke_model.return_value = "Answer"
        db = MagicMock()
        db.retrieve_notes.return_value = [
            _make_mock_doc("Chunk A", date="2023-10-27"),
            _make_mock_doc("Chunk B", date="2024-03-15"),
        ]
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        events = _parse_sse_events(response.text)
        sources = events[-1]["sources"]
        assert sources[0]["date"] == "2023-10-27"
        assert sources[1]["date"] == "2024-03-15"

    def test_sources_fallback_to_unknown_when_date_absent(self):
        llm = MagicMock()
        llm.invoke_model.return_value = "Answer"
        db = MagicMock()
        doc = MagicMock()
        doc.page_content = "Some chunk"
        doc.metadata = {}
        db.retrieve_notes.return_value = [doc]
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        events = _parse_sse_events(response.text)
        sources = events[-1]["sources"]
        assert sources[0]["date"] == "Unknown"

    def test_error_emits_sse_error_event_not_http_500(self):
        llm = MagicMock()
        llm.invoke_model.side_effect = RuntimeError("model unavailable")
        db = MagicMock()
        db.retrieve_notes.return_value = [_make_mock_doc("some text")]
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        assert response.status_code == 200
        events = _parse_sse_events(response.text)
        assert any(e.get("error") for e in events)

    def test_no_notes_returns_fallback_answer_with_empty_sources(self):
        llm = MagicMock()
        db = MagicMock()
        db.retrieve_notes.return_value = []
        client = self._client_with_handlers(llm, db)
        response = client.post("/chat", json=self._CHAT_BODY)
        events = _parse_sse_events(response.text)
        terminal = events[-1]
        assert terminal["done"] is True
        assert "answer" in terminal
        assert terminal["sources"] == []
        llm.invoke_model.assert_not_called()


class TestSummaryGenerateEndpoint:
    _BODY = {"model": "llama3", "party_members": ["Alice", "Bob"]}

    def _client_with_handler(self, summary_handler):
        app = create_app()
        app.dependency_overrides[get_summary_handler] = lambda: summary_handler
        return TestClient(app)

    def _make_summary_handler(self, yields):
        handler = MagicMock()
        handler.generate_summary_streaming.return_value = iter(yields)
        return handler

    def _make_erroring_handler(self):
        handler = MagicMock()
        handler.generate_summary_streaming.side_effect = RuntimeError("no notes found")
        return handler

    def test_returns_200(self):
        handler = self._make_summary_handler([
            (False, 30, "Summarizing section 1 of 2..."),
            (True, 100, "Final campaign summary text."),
        ])
        client = self._client_with_handler(handler)
        response = client.post("/summary/generate", json=self._BODY)
        assert response.status_code == 200

    def test_content_type_is_event_stream(self):
        handler = self._make_summary_handler([(True, 100, "Summary.")])
        client = self._client_with_handler(handler)
        response = client.post("/summary/generate", json=self._BODY)
        assert "text/event-stream" in response.headers["content-type"]

    def test_emits_progress_events_before_terminal(self):
        handler = self._make_summary_handler([
            (False, 20, "Map phase: summarizing chunk 1/3"),
            (False, 40, "Map phase: summarizing chunk 2/3"),
            (True, 100, "Done summary."),
        ])
        client = self._client_with_handler(handler)
        response = client.post("/summary/generate", json=self._BODY)
        events = _parse_sse_events(response.text)
        assert len(events) >= 2
        for event in events[:-1]:
            assert event["done"] is False

    def test_terminal_event_has_done_true_and_progress_100(self):
        handler = self._make_summary_handler([
            (False, 50, "Working..."),
            (True, 100, "Campaign summary."),
        ])
        client = self._client_with_handler(handler)
        response = client.post("/summary/generate", json=self._BODY)
        events = _parse_sse_events(response.text)
        terminal = events[-1]
        assert terminal["done"] is True
        assert terminal["progress"] == 100

    def test_intermediate_events_have_message_field(self):
        handler = self._make_summary_handler([
            (False, 30, "Map phase: summarizing chunk 1/2"),
            (False, 60, "Combining summaries..."),
            (True, 100, "Final."),
        ])
        client = self._client_with_handler(handler)
        response = client.post("/summary/generate", json=self._BODY)
        events = _parse_sse_events(response.text)
        for event in events[:-1]:
            assert "message" in event
            assert "progress" in event

    def test_passes_model_party_members_and_temperature_to_handler(self):
        handler = self._make_summary_handler([(True, 100, "Summary.")])
        client = self._client_with_handler(handler)
        client.post("/summary/generate", json={**self._BODY, "temperature": 0.5})
        handler.generate_summary_streaming.assert_called_once_with(
            "llama3", ["Alice", "Bob"], temperature=0.5
        )

    def test_temperature_defaults_to_0_7_when_not_sent(self):
        handler = self._make_summary_handler([(True, 100, "Summary.")])
        client = self._client_with_handler(handler)
        client.post("/summary/generate", json=self._BODY)
        handler.generate_summary_streaming.assert_called_once_with(
            "llama3", ["Alice", "Bob"], temperature=0.7
        )

    def test_error_emits_sse_error_event_not_http_500(self):
        client = self._client_with_handler(self._make_erroring_handler())
        response = client.post("/summary/generate", json=self._BODY)
        assert response.status_code == 200
        events = _parse_sse_events(response.text)
        assert any(e.get("error") for e in events)


class TestSummaryGetEndpoint:
    _SUMMARY_DATA = {
        "summary": "The party defeated the dragon.",
        "model": "llama3:latest",
        "generated_at": "2024-01-15T10:30:00",
    }

    def _client_with_handler(self, summary_handler):
        app = create_app()
        app.dependency_overrides[get_summary_handler] = lambda: summary_handler
        return TestClient(app)

    def test_returns_200_with_summary_content(self):
        handler = MagicMock()
        handler.get_saved_summary.return_value = self._SUMMARY_DATA
        client = self._client_with_handler(handler)
        response = client.get("/summary")
        assert response.status_code == 200
        data = response.json()
        assert data["summary"] == self._SUMMARY_DATA["summary"]
        assert data["model"] == self._SUMMARY_DATA["model"]
        assert data["generated_at"] == self._SUMMARY_DATA["generated_at"]

    def test_returns_empty_dict_when_no_summary_exists(self):
        handler = MagicMock()
        handler.get_saved_summary.return_value = None
        client = self._client_with_handler(handler)
        response = client.get("/summary")
        assert response.status_code == 200
        assert response.json() == {}


class TestNotesGetEndpoint:
    def test_returns_200_with_content(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Session 1: party arrived at the tavern.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes")
        assert response.status_code == 200
        assert response.json() == {"content": "Session 1: party arrived at the tavern."}

    def test_returns_empty_content_when_file_missing(self, tmp_path, monkeypatch):
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(tmp_path / "nonexistent.txt"))
        response = TestClient(create_app()).get("/notes")
        assert response.status_code == 200
        assert response.json() == {"content": ""}


class TestNotesPostEndpoint:
    def test_returns_200_and_writes_file(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).post("/notes", json={"content": "New notes content."})
        assert response.status_code == 200
        assert notes_file.read_text() == "New notes content."

    def test_overwrites_existing_content(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Old content.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        TestClient(create_app()).post("/notes", json={"content": "Updated notes."})
        assert notes_file.read_text() == "Updated notes."


class TestNotesVectorizeEndpoint:
    def _client_with_db(self, db_handler):
        app = create_app()
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        return TestClient(app)

    def _make_db_handler(self, progress_values: list[float]):
        handler = MagicMock()
        handler.generate_database.return_value = iter(progress_values)
        return handler

    def _make_erroring_db_handler(self):
        handler = MagicMock()
        handler.generate_database.side_effect = RuntimeError("embed error")
        return handler

    def test_returns_200(self):
        client = self._client_with_db(self._make_db_handler([50.0, 100.0]))
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        assert response.status_code == 200

    def test_content_type_is_event_stream(self):
        client = self._client_with_db(self._make_db_handler([50.0]))
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        assert "text/event-stream" in response.headers["content-type"]

    def test_emits_progress_events_before_done(self):
        client = self._client_with_db(self._make_db_handler([33.0, 66.0, 100.0]))
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        events = _parse_sse_events(response.text)
        progress_events = [e for e in events if not e.get("done")]
        assert len(progress_events) >= 1

    def test_terminal_event_has_done_true_and_progress_100(self):
        client = self._client_with_db(self._make_db_handler([50.0]))
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        events = _parse_sse_events(response.text)
        terminal = events[-1]
        assert terminal["done"] is True
        assert terminal["progress"] == 100

    def test_intermediate_events_have_done_false(self):
        client = self._client_with_db(self._make_db_handler([25.0, 50.0, 75.0]))
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        events = _parse_sse_events(response.text)
        for event in events[:-1]:
            assert event["done"] is False

    def test_intermediate_events_have_message_and_progress_fields(self):
        client = self._client_with_db(self._make_db_handler([50.0]))
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        events = _parse_sse_events(response.text)
        progress_events = [e for e in events if not e.get("done")]
        for event in progress_events:
            assert "message" in event
            assert "progress" in event

    def test_error_emits_sse_error_event_not_http_500(self):
        client = self._client_with_db(self._make_erroring_db_handler())
        response = client.post("/notes/vectorize", json={"content": "Session notes here."})
        assert response.status_code == 200
        events = _parse_sse_events(response.text)
        assert any(e.get("error") for e in events)

    def test_calls_generate_database_with_txt_wrapper(self):
        handler = self._make_db_handler([100.0])
        client = self._client_with_db(handler)
        client.post("/notes/vectorize", json={"content": "My notes."})
        handler.generate_database.assert_called_once()
        wrapper_arg = handler.generate_database.call_args[0][0]
        assert wrapper_arg.name.endswith(".txt")
        assert wrapper_arg.getvalue() == b"My notes."

    def test_persists_raw_and_editor_notes_after_successful_vectorize(self):
        df = pd.DataFrame({"Title": ["Entry"], "Date": ["2023-01-01"], "Contents": ["Some notes."]})
        db_handler = MagicMock()
        db_handler.generate_database.return_value = iter([100.0])
        db_handler.last_processed_df = df

        persistence = MagicMock()

        app = create_app()
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        app.dependency_overrides[get_persistence_handler] = lambda: persistence
        client = TestClient(app)
        client.post("/notes/vectorize", json={"content": "Session notes here."})

        persistence.persist.assert_called_once()
        call_args = persistence.persist.call_args[0]
        assert call_args[0] is df
        assert call_args[1] == "Session notes here."

    def test_does_not_persist_when_vectorize_errors(self):
        persistence = MagicMock()
        db_handler = MagicMock()
        db_handler.generate_database.side_effect = RuntimeError("embed error")

        app = create_app()
        app.dependency_overrides[get_db_handler] = lambda: db_handler
        app.dependency_overrides[get_persistence_handler] = lambda: persistence
        client = TestClient(app)
        client.post("/notes/vectorize", json={"content": "Notes."})

        persistence.persist.assert_not_called()


class TestPartyGetEndpoint:
    def test_returns_200_with_party_data_when_file_exists(self, tmp_path, monkeypatch):
        data = {"party_members": [{"name": "Aria", "note_taker": True}, {"name": "Brom", "note_taker": False}]}
        user_data_file = tmp_path / "user_data.json"
        user_data_file.write_text(json.dumps(data))
        import api.main as m
        monkeypatch.setattr(m, "_USER_DATA_FILE", str(user_data_file))
        response = TestClient(create_app()).get("/party")
        assert response.status_code == 200
        body = response.json()
        assert body["party_members"] == data["party_members"]

    def test_returns_empty_list_when_file_missing(self, tmp_path, monkeypatch):
        import api.main as m
        monkeypatch.setattr(m, "_USER_DATA_FILE", str(tmp_path / "nonexistent.json"))
        response = TestClient(create_app()).get("/party")
        assert response.status_code == 200
        assert response.json() == {"party_members": []}

    def test_returns_empty_list_when_party_members_key_absent(self, tmp_path, monkeypatch):
        user_data_file = tmp_path / "user_data.json"
        user_data_file.write_text(json.dumps({"model": "llama3"}))
        import api.main as m
        monkeypatch.setattr(m, "_USER_DATA_FILE", str(user_data_file))
        response = TestClient(create_app()).get("/party")
        assert response.status_code == 200
        assert response.json() == {"party_members": []}


class TestPartyPostEndpoint:
    def test_returns_200_and_writes_party_data(self, tmp_path, monkeypatch):
        user_data_file = tmp_path / "user_data.json"
        import api.main as m
        monkeypatch.setattr(m, "_USER_DATA_FILE", str(user_data_file))
        payload = {"party_members": [{"name": "Aria", "note_taker": True}]}
        response = TestClient(create_app()).post("/party", json=payload)
        assert response.status_code == 200
        saved = json.loads(user_data_file.read_text())
        assert saved["party_members"] == payload["party_members"]

    def test_merges_with_existing_user_data(self, tmp_path, monkeypatch):
        user_data_file = tmp_path / "user_data.json"
        user_data_file.write_text(json.dumps({"model": "llama3", "temperature": 0.7}))
        import api.main as m
        monkeypatch.setattr(m, "_USER_DATA_FILE", str(user_data_file))
        payload = {"party_members": [{"name": "Brom", "note_taker": False}]}
        TestClient(create_app()).post("/party", json=payload)
        saved = json.loads(user_data_file.read_text())
        assert saved["model"] == "llama3"
        assert saved["party_members"] == payload["party_members"]

    def test_creates_file_when_missing(self, tmp_path, monkeypatch):
        user_data_file = tmp_path / "user_data.json"
        import api.main as m
        monkeypatch.setattr(m, "_USER_DATA_FILE", str(user_data_file))
        payload = {"party_members": []}
        response = TestClient(create_app()).post("/party", json=payload)
        assert response.status_code == 200
        assert user_data_file.exists()


class TestNotesExportTxtEndpoint:
    def test_returns_200_with_text_plain_content_type(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Session notes content.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes/export/txt")
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]

    def test_returns_notes_content_as_body(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("My campaign notes.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes/export/txt")
        assert response.content == b"My campaign notes."

    def test_returns_404_when_notes_file_missing(self, tmp_path, monkeypatch):
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(tmp_path / "nonexistent.txt"))
        response = TestClient(create_app()).get("/notes/export/txt")
        assert response.status_code == 404

    def test_includes_content_disposition_header(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Notes.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes/export/txt")
        assert "content-disposition" in response.headers
        assert "editor_notes.txt" in response.headers["content-disposition"]


class TestStatusEndpoint:
    def _client_with_persistence(self, has_notes: bool):
        persistence = MagicMock()
        persistence.has_notes.return_value = has_notes
        app = create_app()
        app.dependency_overrides[get_persistence_handler] = lambda: persistence
        return TestClient(app)

    def test_returns_200(self):
        client = self._client_with_persistence(has_notes=False)
        response = client.get("/status")
        assert response.status_code == 200

    def test_has_notes_false_when_no_raw_notes_file(self):
        client = self._client_with_persistence(has_notes=False)
        response = client.get("/status")
        assert response.json() == {"has_notes": False}

    def test_has_notes_true_when_raw_notes_file_present(self):
        client = self._client_with_persistence(has_notes=True)
        response = client.get("/status")
        assert response.json() == {"has_notes": True}


class TestNotesExportDocxEndpoint:
    def test_returns_200_with_docx_content_type(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Session notes content.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes/export/docx")
        assert response.status_code == 200
        assert "application/vnd.openxmlformats-officedocument.wordprocessingml.document" in response.headers["content-type"]

    def test_returns_non_empty_body(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("My campaign notes.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes/export/docx")
        assert len(response.content) > 0

    def test_returns_404_when_notes_file_missing(self, tmp_path, monkeypatch):
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(tmp_path / "nonexistent.txt"))
        response = TestClient(create_app()).get("/notes/export/docx")
        assert response.status_code == 404

    def test_includes_content_disposition_header(self, tmp_path, monkeypatch):
        notes_file = tmp_path / "editor_notes.txt"
        notes_file.write_text("Notes.")
        import api.main as m
        monkeypatch.setattr(m, "_NOTES_FILE", str(notes_file))
        response = TestClient(create_app()).get("/notes/export/docx")
        assert "content-disposition" in response.headers
        assert "editor_notes.docx" in response.headers["content-disposition"]


class TestBusyRejection:
    """While a heavy operation is in flight, subsequent heavy requests receive a busy response."""

    _CHAT_BODY = {"question": "What happened?", "model": "llama3", "temperature": 0.7}

    def _make_blocking_handlers(self):
        lock_acquired = threading.Event()
        can_proceed = threading.Event()

        def slow_invoke(*args, **kwargs):
            lock_acquired.set()
            can_proceed.wait(timeout=5)
            return "The dragon attacked"

        llm = MagicMock()
        llm.invoke_model.side_effect = slow_invoke
        db = MagicMock()
        db.retrieve_notes.return_value = [_make_mock_doc("Some text")]
        return llm, db, lock_acquired, can_proceed

    def test_second_chat_request_while_first_inflight_receives_busy_response(self):
        llm, db, lock_acquired, can_proceed = self._make_blocking_handlers()

        app = create_app()
        app.dependency_overrides[get_llm_handler] = lambda: llm
        app.dependency_overrides[get_db_handler] = lambda: db
        client = TestClient(app)

        first_result = {}

        def run_first():
            first_result["response"] = client.post("/chat", json=self._CHAT_BODY)

        t = threading.Thread(target=run_first, daemon=True)
        t.start()

        assert lock_acquired.wait(timeout=5), "First request did not reach the LLM call in time"

        second = client.post("/chat", json=self._CHAT_BODY)

        can_proceed.set()
        t.join(timeout=5)

        events = _parse_sse_events(second.text)
        assert any(e.get("error") for e in events), "Expected error event in second response"
        assert any("busy" in e.get("message", "").lower() for e in events), "Expected 'busy' in error message"
