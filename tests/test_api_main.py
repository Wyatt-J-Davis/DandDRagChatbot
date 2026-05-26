"""Tests for the FastAPI application skeleton, /health, and /models endpoints."""
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import create_app, get_llm_handler


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
