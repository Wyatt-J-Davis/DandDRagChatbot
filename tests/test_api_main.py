"""Tests for the FastAPI application skeleton, /health, /models, and /upload-notes endpoints."""
import json
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import create_app, get_llm_handler, get_db_handler, get_summary_handler


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


def _make_mock_doc(content: str) -> MagicMock:
    doc = MagicMock()
    doc.page_content = content
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
        assert events[-1]["sources"] == ["Chunk A", "Chunk B"]

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

    def test_passes_model_and_party_members_to_handler(self):
        handler = self._make_summary_handler([(True, 100, "Summary.")])
        client = self._client_with_handler(handler)
        client.post("/summary/generate", json=self._BODY)
        handler.generate_summary_streaming.assert_called_once_with("llama3", ["Alice", "Bob"])

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
