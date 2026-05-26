"""Tests for the FastAPI application skeleton and /health endpoint."""
import pytest
from fastapi.testclient import TestClient

from api.main import create_app


@pytest.fixture
def client():
    return TestClient(create_app())


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
