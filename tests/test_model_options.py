"""Unit tests for the shared, Streamlit-free ModelOptions module.

This slice exercises only the OpenAI path: a curated list returned without a
key or network call, and immediate persisted-model validation against it.
"""
import pytest
from unittest.mock import MagicMock

from src.utils.LLMHandler import LLMHandler, PROVIDER_OPENAI, PROVIDER_ANTHROPIC
from src.utils.ModelOptions import ModelOptions, SUPPORTED_PROVIDERS, DEFAULT_PROVIDER

_CURATED = ["gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.4"]
_CLAUDE = ["claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5"]
_ANTHROPIC_KEY = "sk-ant-key"


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
        assert ModelOptions.normalize_provider("Gemini") == DEFAULT_PROVIDER

    def test_normalize_coerces_none_to_default(self):
        assert ModelOptions.normalize_provider(None) == DEFAULT_PROVIDER


class TestKeyRouting:
    def test_openai_key_slot(self):
        assert ModelOptions.key_slot(PROVIDER_OPENAI) == "openai_api_key"

    def test_unknown_provider_falls_back_to_default_slot(self):
        assert ModelOptions.key_slot("Gemini") == "openai_api_key"

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


class TestAnthropicProviders:
    def test_anthropic_is_offered(self):
        assert PROVIDER_ANTHROPIC in ModelOptions.providers()

    def test_default_provider_is_still_openai(self):
        assert ModelOptions.default_provider() == PROVIDER_OPENAI

    def test_normalize_keeps_anthropic(self):
        assert ModelOptions.normalize_provider(PROVIDER_ANTHROPIC) == PROVIDER_ANTHROPIC

    def test_anthropic_key_slot_is_separate(self):
        assert ModelOptions.key_slot(PROVIDER_ANTHROPIC) == "anthropic_api_key"

    def test_anthropic_and_openai_slots_differ(self):
        assert ModelOptions.key_slot(PROVIDER_ANTHROPIC) != ModelOptions.key_slot(PROVIDER_OPENAI)

    def test_key_label_names_anthropic(self):
        assert ModelOptions.key_label(PROVIDER_ANTHROPIC) == "Anthropic API Key"


class TestAnthropicResolveModels:
    def test_empty_list_until_key_present(self):
        # No key: empty, no error, no fetch (the page shows the "enter your key" hint).
        llm = MagicMock()
        models, error, _ = ModelOptions(llm).resolve_models(PROVIDER_ANTHROPIC, "", None)
        assert models == []
        assert error is None
        llm.fetch_available_models.assert_not_called()

    def test_fetches_list_from_key(self):
        llm = MagicMock()
        llm.fetch_available_models.return_value = list(_CLAUDE)
        models, error, _ = ModelOptions(llm).resolve_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY, None)
        assert models == _CLAUDE
        assert error is None
        llm.fetch_available_models.assert_called_once_with(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY)

    def test_list_cached_and_reused_across_calls_same_key(self):
        llm = MagicMock()
        llm.fetch_available_models.return_value = list(_CLAUDE)
        opts = ModelOptions(llm)
        _, _, cache = opts.resolve_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY, None)
        models, _, _ = opts.resolve_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY, cache)
        assert models == _CLAUDE
        # Only fetched once — the second call read the cache.
        llm.fetch_available_models.assert_called_once()

    def test_refetches_only_when_key_changes(self):
        llm = MagicMock()
        llm.fetch_available_models.return_value = list(_CLAUDE)
        opts = ModelOptions(llm)
        _, _, cache = opts.resolve_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY, None)
        opts.resolve_models(PROVIDER_ANTHROPIC, "sk-ant-different", cache)
        assert llm.fetch_available_models.call_count == 2

    def test_failed_fetch_surfaces_error_string(self):
        llm = MagicMock()
        llm.fetch_available_models.side_effect = ValueError("Could not reach Anthropic.")
        models, error, _ = ModelOptions(llm).resolve_models(PROVIDER_ANTHROPIC, _ANTHROPIC_KEY, None)
        assert models == []
        assert error == "Could not reach Anthropic."


class TestDeferredValidation:
    def test_keeps_model_when_list_not_yet_available(self):
        # Anthropic before the key is entered: empty list means "defer".
        model, warning = _real_options().validate_persisted_model_deferred("claude-opus-5", [])
        assert model == "claude-opus-5"
        assert warning is None

    def test_drops_model_absent_from_fetched_list(self):
        model, warning = _real_options().validate_persisted_model_deferred("claude-retired", _CLAUDE)
        assert model is None
        assert "claude-retired" in warning
        assert "Model Options" in warning

    def test_keeps_model_present_in_fetched_list(self):
        model, warning = _real_options().validate_persisted_model_deferred("claude-sonnet-5", _CLAUDE)
        assert model == "claude-sonnet-5"
        assert warning is None


class TestPreselectIndex:
    def test_returns_index_of_persisted_model(self):
        assert ModelOptions.preselect_index("gpt-5.4", _CURATED) == 2

    def test_defaults_to_zero_when_absent(self):
        assert ModelOptions.preselect_index("llama3:latest", _CURATED) == 0

    def test_defaults_to_zero_when_none(self):
        assert ModelOptions.preselect_index(None, _CURATED) == 0
