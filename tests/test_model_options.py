"""Unit tests for the shared, Streamlit-free ModelOptions module.

OpenAI is the only backend: a curated list returned without a key or network
call, and immediate persisted-model validation against it.
"""
from unittest.mock import MagicMock

from src.utils.LLMHandler import LLMHandler
from src.utils.ModelOptions import ModelOptions, KEY_SLOT, KEY_LABEL

_CURATED = ["gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4"]


def _real_options():
    return ModelOptions(LLMHandler())


class TestKeyRouting:
    def test_key_slot_is_openai(self):
        assert KEY_SLOT == "openai_api_key"

    def test_key_label_names_openai(self):
        assert KEY_LABEL == "OpenAI API Key"


class TestKnownModels:
    def test_returns_curated_list(self):
        assert _real_options().known_models() == _CURATED


class TestResolveModels:
    def test_returns_curated_list(self):
        models, error = _real_options().resolve_models("")
        assert models == _CURATED
        assert error is None

    def test_needs_no_key_and_no_network(self):
        # A recorder handler proves fetch is a pure list return, never a call
        # that would touch the network.
        llm = MagicMock()
        llm.fetch_available_models.return_value = list(_CURATED)
        models, error = ModelOptions(llm).resolve_models("")
        assert models == _CURATED
        assert error is None
        llm.fetch_available_models.assert_called_once_with("")

    def test_fetch_failure_surfaces_as_error_string(self):
        llm = MagicMock()
        llm.fetch_available_models.side_effect = ValueError("bad key")
        models, error = ModelOptions(llm).resolve_models("")
        assert models == []
        assert error == "bad key"


class TestValidatePersistedModel:
    def test_keeps_model_present_in_list(self):
        model, warning = _real_options().validate_persisted_model("gpt-5.4-mini", _CURATED)
        assert model == "gpt-5.4-mini"
        assert warning is None

    def test_drops_model_absent_from_list(self):
        model, warning = _real_options().validate_persisted_model("llama3:latest", _CURATED)
        assert model is None
        assert "llama3:latest" in warning
        assert "Model Options" in warning

    def test_none_passes_through_without_warning(self):
        model, warning = _real_options().validate_persisted_model(None, _CURATED)
        assert model is None
        assert warning is None


class TestPreselectIndex:
    def test_returns_index_of_persisted_model(self):
        assert ModelOptions.preselect_index("gpt-5.4", _CURATED) == 2

    def test_defaults_to_zero_when_absent(self):
        assert ModelOptions.preselect_index("llama3:latest", _CURATED) == 0

    def test_defaults_to_zero_when_none(self):
        assert ModelOptions.preselect_index(None, _CURATED) == 0
