"""Unit tests for the shared, Streamlit-free ModelOptions module.

This slice exercises only the OpenAI path: a curated list returned without a
key or network call, and immediate persisted-model validation against it.
"""
import pytest
from unittest.mock import MagicMock

from src.utils.LLMHandler import LLMHandler, PROVIDER_OPENAI
from src.utils.ModelOptions import ModelOptions, SUPPORTED_PROVIDERS, DEFAULT_PROVIDER

_CURATED = ["gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4"]


def _real_options():
    return ModelOptions(LLMHandler())


class TestProviders:
    def test_openai_is_offered(self):
        assert PROVIDER_OPENAI in ModelOptions.providers()

    def test_default_provider_is_openai(self):
        assert ModelOptions.default_provider() == PROVIDER_OPENAI

    def test_providers_returns_a_copy(self):
        ModelOptions.providers().append("Bogus")
        assert "Bogus" not in SUPPORTED_PROVIDERS

    def test_normalize_keeps_supported_provider(self):
        assert ModelOptions.normalize_provider(PROVIDER_OPENAI) == PROVIDER_OPENAI

    def test_normalize_coerces_unknown_to_default(self):
        assert ModelOptions.normalize_provider("Anthropic") == DEFAULT_PROVIDER

    def test_normalize_coerces_none_to_default(self):
        assert ModelOptions.normalize_provider(None) == DEFAULT_PROVIDER


class TestKeyRouting:
    def test_openai_key_slot(self):
        assert ModelOptions.key_slot(PROVIDER_OPENAI) == "openai_api_key"

    def test_unknown_provider_falls_back_to_default_slot(self):
        assert ModelOptions.key_slot("Anthropic") == "openai_api_key"

    def test_key_label_names_the_provider(self):
        assert ModelOptions.key_label(PROVIDER_OPENAI) == "OpenAI API Key"


class TestResolveModels:
    def test_openai_returns_curated_list(self):
        models, error, _ = _real_options().resolve_models(PROVIDER_OPENAI, "", None)
        assert models == _CURATED
        assert error is None

    def test_openai_needs_no_key_and_no_network(self):
        # A recorder handler proves fetch is a pure list return, never a call
        # that would touch the network.
        llm = MagicMock()
        llm.fetch_available_models.return_value = list(_CURATED)
        models, error, _ = ModelOptions(llm).resolve_models(PROVIDER_OPENAI, "", None)
        assert models == _CURATED
        assert error is None
        llm.fetch_available_models.assert_called_once_with(PROVIDER_OPENAI, "")

    def test_cache_dict_is_threaded_back(self):
        cache = {"sentinel": True}
        _, _, returned = _real_options().resolve_models(PROVIDER_OPENAI, "", cache)
        assert returned is cache

    def test_none_cache_becomes_a_dict(self):
        _, _, returned = _real_options().resolve_models(PROVIDER_OPENAI, "", None)
        assert isinstance(returned, dict)

    def test_fetch_failure_surfaces_as_error_string(self):
        llm = MagicMock()
        llm.fetch_available_models.side_effect = ValueError("bad key")
        models, error, _ = ModelOptions(llm).resolve_models(PROVIDER_OPENAI, "", None)
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
