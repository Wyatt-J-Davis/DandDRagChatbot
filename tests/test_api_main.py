"""Tests for the FastAPI application skeleton, /health, /models, and /upload-notes endpoints."""
import json
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import create_app, get_llm_handler, get_db_handler


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
